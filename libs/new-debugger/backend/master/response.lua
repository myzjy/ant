local mgr = require 'new-debugger.backend.master.mgr'
local event = require 'new-debugger.backend.master.event'

local response = {}

function response.error(req, msg)
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = false,
        message = msg,
    }
end

function response.success(req, body)
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = body,
    }
end

function response.initialize(req)
    if req.__norepl then
        mgr.newSeq()
        return
    end
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = event._capabilities,
    }
end

function response.threads(req, threads)
    local thds = {}
    for _, id in ipairs(threads) do
        thds[#thds + 1] = {
            name = ('Thread %d'):format(id),
            id = id,
        }
    end
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = {
            threads = thds
        },
    }
end

return response
