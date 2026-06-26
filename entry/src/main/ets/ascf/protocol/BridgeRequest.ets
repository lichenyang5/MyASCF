export interface BridgeRequest {
  requestId: string
  action: string
  params?: Record<string, Object>
  timeout?: number
}

export function parseBridgeRequest(rawReq: string): BridgeRequest {
  let parsed: BridgeRequest
  try {
    parsed = JSON.parse(rawReq) as BridgeRequest
  } catch (e) {
    throw new Error('Invalid JSON')
  }

  const reqId: string = parsed.requestId
  if (typeof reqId !== 'string' || reqId.length === 0) {
    throw new Error('Invalid requestId')
  }

  const action: string = parsed.action
  if (typeof action !== 'string' || action.length === 0) {
    throw new Error('Invalid action')
  }

  return parsed
}
