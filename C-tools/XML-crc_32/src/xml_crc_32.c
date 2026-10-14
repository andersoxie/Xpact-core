/*
 * xml_crc_32 - compute a CRC-32/ISO-HDLC checksum over a chosen data
 * dimension (text, cdata, comment, tag, attribute) of an XML document,
 * parsed with libexpat.
 */

#define _POSIX_C_SOURCE 200809L

#include <expat.h>
#include "shift_jis_subset.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <libgen.h>

typedef enum {
	TYPE_TEXT,
	TYPE_CDATA,
	TYPE_COMMENT,
	TYPE_TAG,
	TYPE_ATTRIBUTE,
	TYPE_PROCESSING,
	TYPE_XML_DECL,
	TYPE_DOCTYPE,
	TYPE_ATTLIST,
	TYPE_ENTITY_DECL,
	TYPE_ENTITY,
	TYPE_NOTATION,
	TYPE_ELEMENT,
	TYPE_XMLNS_DECL
} data_type_t;

static const char *data_type_name[] = {
	"text", "cdata", "comment", "tag", "attribute",
	"processing", "xml-decl", "doctype", "attlist", "entity-decl", "entity", "notation",
	"element", "xmlns-decl"
};

typedef struct {
	data_type_t type;
	int         trace;
	int         verbose_output; /* only true on the first pass */
	uint32_t    crc;
	int         event_count;
	int         in_cdata;
	XML_Parser  parser; /* needed to free XML_Content models handed to on_element_decl */
	int         use_ns; /* non-zero: create the parser with XML_ParserCreateNS */
	char        ns_separator; /* namespace separator character, when use_ns */
	int         ns_triplets; /* non-zero: call XML_SetReturnNSTriplet after creation */
} crc_ctx_t;

static uint32_t crc32_table[256];

static void crc32_table_init(void) {
	for (uint32_t i = 0; i < 256; i++) {
		uint32_t c = i;
		for (int k = 0; k < 8; k++) {
			c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
		}
		crc32_table[i] = c;
	}
}

static void println_escaped(const char *s, int len);

static void crc32_bytes(crc_ctx_t *ctx, const unsigned char *buf, size_t len) {
	uint32_t crc = ctx->crc;
	for (size_t i = 0; i < len; i++) {
		crc = crc32_table[(crc ^ buf[i]) & 0xFFu] ^ (crc >> 8);
	}
	ctx->crc = crc;
	ctx->event_count++;
}

static void crc32_update(crc_ctx_t *ctx, const unsigned char *buf, size_t len) {
	crc32_bytes(ctx, buf, len);
	if (ctx->trace && ctx->verbose_output) {
		printf("#%07d (%u): \"", ctx->event_count, ctx->crc ^ 0xFFFFFFFFu);
		println_escaped ((const char *) buf, len);
	}
}

/* Same CRC update as crc32_update, but for a signed 32-bit value fed in as
 * 4 raw big-endian bytes; traced as a decimal integer rather than an
 * escaped byte string. Used for the XML declaration's standalone field. */
static void crc32_update_int32(crc_ctx_t *ctx, int32_t value) {
	crc32_bytes(ctx, (const unsigned char *)&value, sizeof(int32_t));
	if (ctx->trace && ctx->verbose_output) {
		printf("#%07d (%u): %d\n", ctx->event_count, ctx->crc ^ 0xFFFFFFFFu, value);
	}
}

/* Same CRC update as crc32_update, but for a boolean value fed in as a
 * single byte (0 or 1); traced as "True"/"False" rather than an escaped
 * byte string. Used for the doctype's has_internal_subset field. */
static void crc32_update_bool(crc_ctx_t *ctx, int value) {
	unsigned char byte = value ? 1u : 0u;
	crc32_bytes(ctx, &byte, sizeof(byte));
	if (ctx->trace && ctx->verbose_output) {
		printf("#%07d (%u): %s\n", ctx->event_count, ctx->crc ^ 0xFFFFFFFFu,
		       value ? "True" : "False");
	}
}

/* qsort comparator for canonicalize_context: plain byte-wise ordering, via
 * strcmp -- just needs a total order, not locale collation. */
static int compare_context_field(const void *a, const void *b) {
	const char *const *pa = (const char *const *) a;
	const char *const *pb = (const char *const *) b;
	return strcmp(*pa, *pb);
}

/* Returns a newly malloc'd, reordered copy of `context' for a run-to-run
 * stable checksum/trace. expat's `context' joins CONTEXT_SEP (ASCII FF,
 * '\f')-separated fields built by getContext() (xmlparse.c:7352-7436) in a
 * fixed *category* order: the default namespace binding ("=uri") if any,
 * then every other active prefix binding ("prefix=uri"), then every
 * currently open general entity's name, in that order, unconditionally --
 * see getContext()'s own source, which processes dtd->prefixes and only
 * then dtd->generalEntities, with no interleaving. So an entity name is
 * always guaranteed to come after every namespace-binding field already,
 * by construction; what's NOT guaranteed is the order *within* each
 * category, since that comes from iterating a hash table keyed with
 * libexpat's own per-process-random SipHash salt (xmlparse.c:1111-1120),
 * which varies from run to run even for the same document.
 *
 * To cancel that out, every "=" field (a namespace binding -- an entity
 * name never contains '=') is sorted alphabetically; every non-"=" field
 * (an entity name) is left in its original relative order, after all the
 * "=" fields -- which just makes explicit the category order getContext()
 * already guarantees, rather than relying on it implicitly. Note: if more
 * than one entity is simultaneously open (nested external-entity
 * references), their *mutual* order is drawn from that same salted hash
 * table and is therefore just as nondeterministic as the namespace
 * bindings -- this function does not address that case, only the
 * namespace-binding ordering actually observed so far. Caller must
 * free() the result; returns NULL on allocation failure. */
static char *canonicalize_context(const char *context) {
	size_t len = strlen(context);
	size_t field_count = 1, ns_count = 0, entity_count = 0, i;
	char *scratch, *out, *p;
	char **fields, **ns_fields, **entity_fields;

	scratch = (char *) malloc(len + 1);
	if (! scratch) return NULL;
	memcpy(scratch, context, len + 1);

	for (i = 0; i < len; i++)
		if (scratch[i] == '\f')
			field_count++;

	fields = (char **) malloc(field_count * sizeof(char *));
	ns_fields = (char **) malloc(field_count * sizeof(char *));
	entity_fields = (char **) malloc(field_count * sizeof(char *));
	out = (char *) malloc(len + 1); /* same characters, just reordered */
	if (! fields || ! ns_fields || ! entity_fields || ! out) {
		free(scratch); free(fields); free(ns_fields); free(entity_fields); free(out);
		return NULL;
	}

	field_count = 0;
	fields[field_count++] = scratch;
	for (i = 0; i < len; i++) {
		if (scratch[i] == '\f') {
			scratch[i] = '\0';
			fields[field_count++] = scratch + i + 1;
		}
	}

	for (i = 0; i < field_count; i++) {
		if (strchr(fields[i], '='))
			ns_fields[ns_count++] = fields[i];
		else
			entity_fields[entity_count++] = fields[i];
	}

	qsort(ns_fields, ns_count, sizeof(char *), compare_context_field);

	p = out;
	for (i = 0; i < ns_count; i++) {
		size_t field_len = strlen(ns_fields[i]);
		if (i > 0) *p++ = '\f';
		memcpy(p, ns_fields[i], field_len);
		p += field_len;
	}
	for (i = 0; i < entity_count; i++) {
		size_t field_len = strlen(entity_fields[i]);
		if (p != out) *p++ = '\f';
		memcpy(p, entity_fields[i], field_len);
		p += field_len;
	}
	*p = '\0';

	free(scratch);
	free(fields);
	free(ns_fields);
	free(entity_fields);
	return out;
}

/* Stub handler for external parameter entities (e.g. %selectors; in XSL files).
 * Without this, expat sets dtd->keepProcessing=false when it hits an external
 * parameter entity ref and has no handler, which silently discards all entity
 * declarations that follow it in the internal subset.
 * Calling XML_Parse on the sub-parser (even with empty content) sets
 * dtd->paramEntityRead=true, which keeps keepProcessing=true.
 *
 * Also combines its own arguments, left to right, into the checksum --
 * but which -type and which arguments depends on whether context is NULL,
 * since that's what distinguishes a genuine general-entity reference from
 * a DTD-related one. context is NULL only when the reference is to a
 * parameter entity -- which includes not just an explicit %name; but also
 * expat's own read of a DOCTYPE's external subset (SYSTEM/PUBLIC id),
 * internally modelled as a reference to a pseudo parameter entity; see
 * xmlparse.c:5399-5401. So:
 *   - context non-NULL (-type entity): a real external *general* entity
 *     reference (&name; resolved externally). context, base, systemId,
 *     publicId are all combined, left to right.
 *   - context NULL (-type entity-decl): a DTD-related event -- a genuine
 *     %name; reference, or just the external-subset read triggered by the
 *     DOCTYPE's own SYSTEM/PUBLIC id, with no %name;/&name; in the
 *     document at all. context itself is skipped (it's NULL either way);
 *     base, systemId, publicId are combined, left to right.
 * In both cases base/systemId/publicId are individually skipped when NULL
 * (base is NULL unless XML_SetBase was called, which this program never
 * does; systemId is never NULL; publicId is NULL unless a PUBLIC
 * identifier was given). `parser' itself (the referencing parser, used
 * below only to create the sub-parser) isn't document data, so it isn't
 * checksummed; `ctx' is recovered from it via XML_GetUserData rather than
 * received directly, since this handler's own first argument is the
 * parser, not userData. */
static int XMLCALL on_external_entity(XML_Parser parser,
                                      const XML_Char *context,
                                      const XML_Char *base,
                                      const XML_Char *systemId,
                                      const XML_Char *publicId)
{
	crc_ctx_t *ctx = (crc_ctx_t *) XML_GetUserData(parser);
	XML_Bool add_external_id = XML_FALSE;
	switch (ctx->type){
		case TYPE_ENTITY:
			if (context){
				char *canon_context = canonicalize_context(context);
				if (canon_context) {
					crc32_update(ctx, (const unsigned char *) canon_context, strlen(canon_context));
					free(canon_context);
				} else {
					crc32_update(ctx, (const unsigned char *) context, strlen(context));
				}
				add_external_id = XML_TRUE;
			}
			break;
			
		case TYPE_ENTITY_DECL:
			if (! context)
				add_external_id = XML_TRUE;
			break;
		default:
			break;
		
	}
	if (add_external_id) {
		if (base)
			crc32_update(ctx, (const unsigned char *) base, strlen(base));
		if (systemId)
			crc32_update(ctx, (const unsigned char *) systemId, strlen(systemId));
		if (publicId)
			crc32_update(ctx, (const unsigned char *) publicId, strlen(publicId));
	}

	XML_Parser sub = XML_ExternalEntityParserCreate(parser, context, NULL);
	if (sub) {
		XML_Parse(sub, "", 0, 1);
		XML_ParserFree(sub);
	}
	return 1;
}

static void XMLCALL on_start_cdata(void *userData) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	ctx->in_cdata = 1;
}

static void XMLCALL on_end_cdata(void *userData) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	ctx->in_cdata = 0;
}

static void XMLCALL on_character_data(void *userData, const XML_Char *s, int len) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_TEXT && !ctx->in_cdata) {
		crc32_update(ctx, (const unsigned char *) s, (size_t) len);
	} else if (ctx->type == TYPE_CDATA && ctx->in_cdata) {
		crc32_update(ctx, (const unsigned char *) s, (size_t) len);
	}
}

static void XMLCALL on_processing_instruction(void *userData,
                                               const XML_Char *target,
                                               const XML_Char *data) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_PROCESSING) {
		crc32_update(ctx, (const unsigned char *) target, strlen(target));
		if (data && *data)
			crc32_update(ctx, (const unsigned char *) data, strlen(data));
	}
}

static void XMLCALL on_comment(void *userData, const XML_Char *data) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_COMMENT) {
		crc32_update(ctx, (const unsigned char *) data, strlen(data));
	}
}

static void XMLCALL on_start_element(void *userData, const XML_Char *name,
									  const XML_Char **atts) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_TAG) {
		crc32_update(ctx, (const unsigned char *) name, strlen(name));
	} else if (ctx->type == TYPE_ATTRIBUTE) {
		for (int i = 0; atts[i]; i += 2) {
			crc32_update(ctx, (const unsigned char *) atts[i], strlen(atts[i]));
			crc32_update(ctx, (const unsigned char *) atts[i + 1], strlen(atts[i + 1]));
		}
	}
}

/* Combines the XML declaration's version, encoding and standalone fields
 * (as supplied to XML_XmlDeclHandler) into the running checksum. encoding
 * is NULL when absent from the declaration; standalone is -1 when absent,
 * 0 for standalone="no", 1 for standalone="yes". */
static void XMLCALL on_xml_decl(void *userData, const XML_Char *version,
                                 const XML_Char *encoding, int standalone) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_XML_DECL) return;
	if (version)
		crc32_update(ctx, (const unsigned char *) version, strlen(version));
	if (encoding)
		crc32_update(ctx, (const unsigned char *) encoding, strlen(encoding));
	crc32_update_int32 (ctx, standalone); // can have -1 as value, so not a boolean
}

/* ISO-8859-15 (Latin-9) departs from a pure byte-for-codepoint identity
 * mapping at exactly these 8 positions; every other byte 0x00-0xFF maps to
 * the Unicode code point of the same value, which also covers the required
 * ASCII-identity range 0x00-0x7F. */
static const struct { unsigned char byte; int codepoint; } iso_8859_15_overrides[] = {
	{0xA4, 0x20AC}, /* EURO SIGN */
	{0xA6, 0x0160}, /* LATIN CAPITAL LETTER S WITH CARON */
	{0xA8, 0x0161}, /* LATIN SMALL LETTER S WITH CARON */
	{0xB4, 0x017D}, /* LATIN CAPITAL LETTER Z WITH CARON */
	{0xB8, 0x017E}, /* LATIN SMALL LETTER Z WITH CARON */
	{0xBC, 0x0152}, /* LATIN CAPITAL LIGATURE OE */
	{0xBD, 0x0153}, /* LATIN SMALL LIGATURE OE */
	{0xBE, 0x0178}  /* LATIN CAPITAL LETTER Y WITH DIAERESIS */
};

/* XML_UnknownEncodingHandler for ISO-8859-15 and Shift_JIS_subset: the only
 * unrecognized encoding names this program knows how to decode.
 * encodingHandlerData is `ctx' (set via XML_SetUnknownEncodingHandler's own,
 * separate data argument, distinct from XML_SetUserData's userData).
 * ISO-8859-15 fills in `info->map' with a single-byte encoding (no
 * multi-byte sequences, so `convert'/`release'/`data' are left unused);
 * Shift_JIS_subset is delegated entirely to the shift_jis_subset static
 * library (see shift_jis_subset.h) -- shared with the Xpact Eiffel project,
 * since it never names expat's own XML_Encoding type, only its layout. As
 * with XML_XmlDeclHandler's `encoding' argument, `name' is added to the
 * checksum when -type is xml-decl. Returns XML_STATUS_ERROR for any other
 * encoding name, or if shift_jis_subset_fill_encoding couldn't allocate its
 * lookup table. */
static int XMLCALL on_unknown_encoding(void *encodingHandlerData,
                                        const XML_Char *name,
                                        XML_Encoding *info) {
	crc_ctx_t *ctx = (crc_ctx_t *) encodingHandlerData;
	size_t i;
	int result = XML_STATUS_ERROR;

	if (strcasecmp(name, "ISO-8859-15") == 0){
		for (i = 0; i < 256; i++)
			info->map[i] = (int) i;
		for (i = 0; i < sizeof(iso_8859_15_overrides) / sizeof(iso_8859_15_overrides[0]); i++)
			info->map[iso_8859_15_overrides[i].byte] = iso_8859_15_overrides[i].codepoint;
		info->data = NULL;
		info->convert = NULL;
		info->release = NULL;
		result = XML_STATUS_OK;
	} else if (strcasecmp(name, "Shift_JIS_subset") == 0) {
		if (shift_jis_subset_fill_encoding(info))
			result = XML_STATUS_OK;
	}

	if (ctx->type == TYPE_XML_DECL)
		crc32_update(ctx, (const unsigned char *) name, strlen(name));

	return result;
}

/* Combines the DOCTYPE declaration's name, external ID keyword ("PUBLIC" or
 * "SYSTEM", omitted when neither id is present), public id, system id and
 * has_internal_subset flag (as supplied to XML_StartDoctypeDeclHandler)
 * into the running checksum. */
static void XMLCALL on_start_doctype_decl(void *userData, const XML_Char *doctypeName,
                                           const XML_Char *sysid, const XML_Char *pubid,
                                           int has_internal_subset) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_DOCTYPE) return;
	crc32_update(ctx, (const unsigned char *) doctypeName, strlen(doctypeName));
	if (pubid) {
		crc32_update(ctx, (const unsigned char *) pubid, strlen(pubid));
		if (sysid)
			crc32_update(ctx, (const unsigned char *) sysid, strlen(sysid));
	} else if (sysid) {
		crc32_update(ctx, (const unsigned char *) sysid, strlen(sysid));
	}
	crc32_update_bool(ctx, has_internal_subset);
}

/* Combines the ATTLIST declaration's fields, left to right as supplied to
 * XML_AttlistDeclHandler, into the running checksum: elname, attname,
 * att_type, dflt (skipped when NULL), isrequired. */
static void XMLCALL on_attlist_decl(void *userData, const XML_Char *elname,
                                     const XML_Char *attname, const XML_Char *att_type,
                                     const XML_Char *dflt, int isrequired) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_ATTLIST) return;
	crc32_update(ctx, (const unsigned char *) elname, strlen(elname));
	crc32_update(ctx, (const unsigned char *) attname, strlen(attname));
	crc32_update(ctx, (const unsigned char *) att_type, strlen(att_type));
	if (dflt)
		crc32_update(ctx, (const unsigned char *) dflt, strlen(dflt));
	crc32_update_bool(ctx, isrequired);
}

/* Combines the ENTITY declaration's fields, left to right as supplied to
 * XML_EntityDeclHandler, into the running checksum: entityName,
 * is_parameter_entity, value, base, systemId, publicId, notationName.
 * value is not NUL-terminated, so value_length is used directly rather
 * than strlen; value/base/systemId/publicId/notationName are skipped
 * when NULL. */
static void XMLCALL on_entity_decl(void *userData, const XML_Char *entityName,
                                    int is_parameter_entity, const XML_Char *value,
                                    int value_length, const XML_Char *base,
                                    const XML_Char *systemId, const XML_Char *publicId,
                                    const XML_Char *notationName) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_ENTITY_DECL) return;
	crc32_update(ctx, (const unsigned char *) entityName, strlen(entityName));
	crc32_update_bool(ctx, is_parameter_entity);
	if (value){
		crc32_update(ctx, (const unsigned char *) value, (size_t) value_length);
		crc32_update_int32(ctx, value_length);
	}
	if (base)
		crc32_update(ctx, (const unsigned char *) base, strlen(base));
	if (systemId)
		crc32_update(ctx, (const unsigned char *) systemId, strlen(systemId));
	if (publicId)
		crc32_update(ctx, (const unsigned char *) publicId, strlen(publicId));
	if (notationName)
		crc32_update(ctx, (const unsigned char *) notationName, strlen(notationName));
}

/* Combines the unparsed-entity declaration's fields, left to right as supplied
 * to XML_UnparsedEntityDeclHandler, into the running checksum: entityName,
 * base, systemId, publicId, notationName. Adds to the same checksum as
 * XML_EntityDeclHandler (-type entity-decl). expat calls the two handlers
 * mutually exclusively per entity: for an unparsed (NDATA) entity it calls
 * *this* handler instead of XML_EntityDeclHandler (only falling back to
 * XML_EntityDeclHandler, with notationName forced NULL, when no
 * XML_UnparsedEntityDeclHandler is registered at all -- see
 * XML_ROLE_ENTITY_NOTATION_NAME in xmlparse.c); XML_EntityDeclHandler alone
 * still handles every other (internal or parsed-external) entity. So
 * registering this handler doesn't double-count anything -- it replaces the
 * lossy fallback for unparsed entities and, unlike that fallback, correctly
 * folds notationName into the checksum too. entityName and notationName are
 * never NULL for this handler; base/systemId/publicId are skipped when
 * NULL. */
static void XMLCALL on_unparsed_entity_decl(void *userData, const XML_Char *entityName,
                                             const XML_Char *base, const XML_Char *systemId,
                                             const XML_Char *publicId,
                                             const XML_Char *notationName) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_ENTITY_DECL) return;
	crc32_update(ctx, (const unsigned char *) entityName, strlen(entityName));
	if (base)
		crc32_update(ctx, (const unsigned char *) base, strlen(base));
	if (systemId)
		crc32_update(ctx, (const unsigned char *) systemId, strlen(systemId));
	if (publicId)
		crc32_update(ctx, (const unsigned char *) publicId, strlen(publicId));
	crc32_update(ctx, (const unsigned char *) notationName, strlen(notationName));
}

/* Combines the skipped-entity fields, left to right as supplied to
 * XML_SkippedEntityHandler, into the running checksum: entityName,
 * is_parameter_entity. This is -type entity, kept separate from
 * -type entity-decl (XML_EntityDeclHandler / XML_UnparsedEntityDeclHandler):
 * a skipped entity was never declared or parsed at all -- it's reported
 * instead of a declaration, not alongside one (an undefined entity
 * reference that isn't an error, or a known internal entity deliberately
 * left unexpanded because XML_SetDefaultHandler rather than
 * XML_SetDefaultHandlerExpand was registered -- see XML_SkippedEntityHandler
 * in expat.h). entityName is never NULL for this handler. */
 
static void XMLCALL on_skipped_entity(
	void *userData, const XML_Char *entityName, int is_parameter_entity) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_ENTITY){
		crc32_update(ctx, (const unsigned char *) entityName, strlen(entityName));
		crc32_update_bool(ctx, is_parameter_entity);
	}
}

/* Combines the NOTATION declaration's fields, left to right as supplied to
 * XML_NotationDeclHandler, into the running checksum: notationName, base,
 * systemId, publicId. notationName is never NULL; base/systemId/publicId
 * are skipped when NULL. */
static void XMLCALL on_notation_decl(void *userData, const XML_Char *notationName,
                                      const XML_Char *base, const XML_Char *systemId,
                                      const XML_Char *publicId) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_NOTATION) return;
	crc32_update(ctx, (const unsigned char *) notationName, strlen(notationName));
	if (base)
		crc32_update(ctx, (const unsigned char *) base, strlen(base));
	if (systemId)
		crc32_update(ctx, (const unsigned char *) systemId, strlen(systemId));
	if (publicId)
		crc32_update(ctx, (const unsigned char *) publicId, strlen(publicId));
}

/* Same CRC update as crc32_update_int32, but for tracing an enumerated value:
 * when annotation is non-NULL, it is appended to the trace line as an
 * Eiffel-style comment, e.g. "6 -- Sequence". Used for the XML_Content
 * type/quant fields. */
static void crc32_update_int32_annotated(crc_ctx_t *ctx, int32_t value,
                                          const char *annotation) {
	crc32_bytes(ctx, (const unsigned char *)&value, sizeof(int32_t));
	if (ctx->trace && ctx->verbose_output) {
		printf("#%07d (%u): %d", ctx->event_count, ctx->crc ^ 0xFFFFFFFFu, value);
		if (annotation)
			printf(" -- %s", annotation);
		putchar('\n');
	}
}

/* Name of an XML_Content_Type value, for trace annotation; NULL if out of range. */
static const char *content_type_name(enum XML_Content_Type type) {
	switch (type) {
		case XML_CTYPE_EMPTY:  return "Empty";
		case XML_CTYPE_ANY:    return "Any";
		case XML_CTYPE_MIXED:  return "Mixed";
		case XML_CTYPE_NAME:   return "Name";
		case XML_CTYPE_CHOICE: return "Choice";
		case XML_CTYPE_SEQ:    return "Sequence";
		default:               return NULL;
	}
}

/* Name of an XML_Content_Quant value, for trace annotation; NULL if out of range. */
static const char *content_quant_name(enum XML_Content_Quant quant) {
	switch (quant) {
		case XML_CQUANT_NONE: return "None";
		case XML_CQUANT_OPT:  return "Option";
		case XML_CQUANT_REP:  return "Repetition";
		case XML_CQUANT_PLUS: return "Plus";
		default:              return NULL;
	}
}

/* Recursively combines one XML_Content particle's fields, left to right, into
 * the running checksum: type, quant, name (skipped when NULL), numchildren,
 * then each child in the children array, in order. Used by on_element_decl
 * to fold in the recursive content model returned for an <!ELEMENT ...>
 * declaration. type and quant are traced with their enumeration names. */
static void crc32_update_content(crc_ctx_t *ctx, XML_Content *model) {
	unsigned int i;
	crc32_update_int32_annotated(ctx, (int32_t) model->type, content_type_name(model->type));
	crc32_update_int32_annotated(ctx, (int32_t) model->quant, content_quant_name(model->quant));
	if (model->name)
		crc32_update(ctx, (const unsigned char *) model->name, strlen(model->name));
	crc32_update_int32(ctx, (int32_t) model->numchildren);
	for (i = 0; i < model->numchildren; i++) {
		crc32_update_content(ctx, &model->children[i]);
	}
}

/* Combines the ELEMENT declaration's fields into the running checksum, as
 * supplied to XML_ElementDeclHandler: first the element name, then the
 * recursive content model (type, quant, name, numchildren and children,
 * see crc32_update_content). An EMPTY or ANY declaration is still
 * represented by a non-NULL model (of type XML_CTYPE_EMPTY / XML_CTYPE_ANY);
 * model is only NULL if expat itself failed to allocate one, in which case
 * there is nothing further to checksum. Per the eXpat API contract, the
 * model must be freed by the caller once done with it. */
static void XMLCALL on_element_decl(void *userData, const XML_Char *name,
                                     XML_Content *model) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type == TYPE_ELEMENT) {
		crc32_update(ctx, (const unsigned char *) name, strlen(name));
		if (model)
			crc32_update_content(ctx, model);
	}
	if (model)
		XML_FreeContentModel(ctx->parser, model);
}

/* Combines the namespace declaration's fields, left to right as supplied to
 * XML_StartNamespaceDeclHandler / XML_EndNamespaceDeclHandler, into the
 * running checksum: prefix then uri for a start event, just prefix for an
 * end event. prefix is NULL for a default (unprefixed) "xmlns" declaration;
 * uri is NULL for an "xmlns=''" declaration undeclaring the default
 * namespace; both are skipped when NULL. These handlers only ever fire when
 * the parser was created with XML_ParserCreateNS (see -xmlns), since
 * namespace processing must be enabled for expat to recognize xmlns
 * declarations as such rather than as ordinary attributes. */
static void XMLCALL on_start_namespace_decl(void *userData, const XML_Char *prefix,
                                             const XML_Char *uri) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_XMLNS_DECL) return;
	if (prefix)
		crc32_update(ctx, (const unsigned char *) prefix, strlen(prefix));
	if (uri)
		crc32_update(ctx, (const unsigned char *) uri, strlen(uri));
}

static void XMLCALL on_end_namespace_decl(void *userData, const XML_Char *prefix) {
	crc_ctx_t *ctx = (crc_ctx_t *) userData;
	if (ctx->type != TYPE_XMLNS_DECL) return;
	if (prefix)
		crc32_update(ctx, (const unsigned char *) prefix, strlen(prefix));
}

#define CHUNK_SIZE 4096

/* Parses the file incrementally in 4096-byte chunks, feeding events into ctx.
 * Returns the finalized CRC-32 value for this pass. */
static uint32_t run_pass(const char *file_path, crc_ctx_t *ctx) {
	ctx->crc = 0xFFFFFFFFu;
	ctx->event_count = 0;
	ctx->in_cdata = 0;

	FILE *fp = fopen(file_path, "rb");
	if (!fp) {
		fprintf(stderr, "Error: could not open file '%s'\n", file_path);
		exit(1);
	}

	XML_Parser parser = ctx->use_ns
		? XML_ParserCreateNS(NULL, ctx->ns_separator)
		: XML_ParserCreate(NULL);
	if (!parser) {
		fprintf(stderr, "Error: could not create expat parser\n");
		fclose(fp);
		exit(1);
	}

	ctx->parser = parser;

	if (ctx->ns_triplets)
		XML_SetReturnNSTriplet(parser, 1);

	XML_SetUserData(parser, ctx);
	XML_SetParamEntityParsing(parser, XML_PARAM_ENTITY_PARSING_ALWAYS);
	XML_SetExternalEntityRefHandler(parser, on_external_entity);
	XML_SetElementHandler(parser, on_start_element, NULL);
	XML_SetCharacterDataHandler(parser, on_character_data);
	XML_SetCommentHandler(parser, on_comment);
	XML_SetCdataSectionHandler(parser, on_start_cdata, on_end_cdata);
	XML_SetProcessingInstructionHandler(parser, on_processing_instruction);
	XML_SetXmlDeclHandler(parser, on_xml_decl);
	XML_SetUnknownEncodingHandler(parser, on_unknown_encoding, ctx);
	XML_SetStartDoctypeDeclHandler(parser, on_start_doctype_decl);
	XML_SetAttlistDeclHandler(parser, on_attlist_decl);
	XML_SetEntityDeclHandler(parser, on_entity_decl);
	XML_SetUnparsedEntityDeclHandler(parser, on_unparsed_entity_decl);
	XML_SetSkippedEntityHandler(parser, on_skipped_entity);
	XML_SetNotationDeclHandler(parser, on_notation_decl);
	XML_SetElementDeclHandler(parser, on_element_decl);
	XML_SetNamespaceDeclHandler(parser, on_start_namespace_decl, on_end_namespace_decl);

	char buf[CHUNK_SIZE];
	int done = 0;
	while (!done) {
		size_t len = fread(buf, 1, CHUNK_SIZE, fp);
		done = len < CHUNK_SIZE;
		if (XML_Parse(parser, buf, (int) len, done) == XML_STATUS_ERROR) {
			fprintf(stderr, "Parse error: %s at line %lu\n",
					XML_ErrorString(XML_GetErrorCode(parser)),
					XML_GetCurrentLineNumber(parser));
			XML_ParserFree(parser);
			fclose(fp);
			exit(1);
		}
	}

	fclose(fp);
	uint32_t result = ctx->crc ^ 0xFFFFFFFFu;
	XML_ParserFree(parser);
	return result;
}

static long now_ms(void) {
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return ts.tv_sec * 1000L + ts.tv_nsec / 1000000L;
}

static void usage(const char *prog) {
	fprintf(stderr,
			"Usage: %s -type <text|cdata|comment|tag|attribute|"
			"processing|xml-decl|doctype|attlist|entity-decl|entity|notation|element|xmlns-decl> "
			"[-duration <time-window-ms>] [-trace] [-xmlns [<separator>]] [-ns_triplets] "
			"<xml-file-path>\n",
			prog);
}

/* Index i corresponds to ASCII code i + '\b' (8), covering the control-
 * character range BS(8)..CR(13); '\0' means "no escape" (e.g. VT, 11).
 * Mirrors `escape_characters' in EL_TRACEABLE_CRC_32_DIGEST.put_indexable. */
static const char escape_table[] = {
	'B', /* BS (backspace, 8) */
	'T', /* HT (tab, 9) */
	'N', /* NL (newline, 10) */
	'\0', /* VT (11) -- no escape */
	'F', /* FF (form feed, 12) -- expat's CONTEXT_SEP */
	'R'  /* CR (carriage return, 13) */
};

static void println_escaped (const char *s, int len) {
	for (int i = 0; i < len; i++) {
		unsigned char code = (unsigned char) s[i];
		char escape = '\0';
		if (code >= '\b' && code <= '\r')
			escape = escape_table[code - '\b'];
		if (escape) {
			putchar('%');
			putchar(escape);
		} else {
			putchar(s[i]);
		}
	}
	putchar('"');
	putchar('\n');
}

#include <stdio.h>

// claude --resume 344f37b9-23a1-4eac-94de-245352a8d82d

int main(int argc, char **argv) {
	const char *type_arg = NULL;
	const char *file_path = NULL;
	long duration_ms = 0;
	int trace = 0;
	int use_ns = 0;
	char ns_separator = '|'; /* default when -xmlns is given without a separator */
	int ns_triplets = 0;

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-type") == 0) {
			if (++i >= argc) { usage(argv[0]); return 1; }
			type_arg = argv[i];
		} else if (strcmp(argv[i], "-duration") == 0) {
			if (++i >= argc) { usage(argv[0]); return 1; }
			duration_ms = strtol(argv[i], NULL, 10);
		} else if (strcmp(argv[i], "-trace") == 0) {
			trace = 1;
		} else if (strcmp(argv[i], "-xmlns") == 0) {
			use_ns = 1;
			/* the separator is itself optional: only consume the next argument
			 * as the separator when it looks like exactly one character, so a
			 * following flag or the file path is never swallowed by mistake. */
			if (i + 1 < argc && strlen(argv[i + 1]) == 1) {
				ns_separator = argv[++i][0];
			}
		} else if (strcmp(argv[i], "-ns_triplets") == 0) {
			ns_triplets = 1;
		} else {
			file_path = argv[i];
		}
	}

	if (!type_arg || !file_path) {
		usage(argv[0]);
		return 1;
	}

	// match data_type enum with argument -type 
	data_type_t type = TYPE_TEXT;
	int type_found = 0;
	for (size_t i = 0; i < sizeof(data_type_name) / sizeof(data_type_name[0]); i++) {
		if (strcmp(type_arg, data_type_name[i]) == 0) {
			type = (data_type_t) i;
			type_found = 1;
			break;
		}
	}
	if (!type_found) {
		fprintf(stderr, "Error: invalid -type '%s'\n", type_arg);
		usage(argv[0]);
		return 1;
	}

	crc32_table_init();

	char *path_copy = strdup(file_path);
	printf("Program: eXpat XML CRC-32 parser (C lang)\n");
	printf("Parsing: %s\n", basename(path_copy));
	free(path_copy);

	crc_ctx_t ctx;
	ctx.type = type;
	ctx.trace = trace;
	ctx.use_ns = use_ns;
	ctx.ns_separator = ns_separator;
	ctx.ns_triplets = ns_triplets;

	ctx.verbose_output = 1;
	uint32_t checksum = run_pass(file_path, &ctx);
	printf("Checksum for %s: %u\n", data_type_name[type], checksum);

	if (duration_ms > 0) {
		ctx.verbose_output = 0;
		long start = now_ms();
		long passes = 1; /* the pass already completed above */
		while (now_ms() - start < duration_ms) {
			run_pass(file_path, &ctx);
			passes++;
		}
		printf("Number of passes in %ld ms: %ld\n", duration_ms, passes);
	}

	return 0;
}
