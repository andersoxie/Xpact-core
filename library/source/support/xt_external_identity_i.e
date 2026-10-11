note
	description: "Object that has a public and/or system id"

	author: "Finnian Reilly"
	copyright: "Copyright (c) 2001-2026 Finnian Reilly"
	contact: "finnian at eiffel hyphen loop dot com"

	license: "MIT license (See: en.wikipedia.org/wiki/MIT_License)"

	date: "2026-10-10 17:00:00 GMT (Saturday 10th October 2026)"
	revision: "1"

deferred class
	XT_EXTERNAL_IDENTITY_I

feature -- Access

	public_id: detachable STRING
		deferred
		end

	system_id: detachable STRING
		deferred
		end

end
