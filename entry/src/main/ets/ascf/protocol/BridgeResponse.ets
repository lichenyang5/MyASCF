export const CODE_SUCCESS: number = 0
export const CODE_PARAMS_ERROR: number = 400
export const CODE_UNKNOWN_ACTION: number = 404
export const CODE_TIMEOUT: number = 408
export const CODE_NATIVE_ERROR: number = 500

export interface BridgeResponse {
  requestId: string
  code: number
  message: string
  data?: Record<string, Object>
}

export function successResponse(
  requestId: string,
  message: string,
  data?: Record<string, Object>
): BridgeResponse {
  const resp: BridgeResponse = {
    requestId: requestId,
    code: CODE_SUCCESS,
    message: message,
    data: data
  }
  return resp
}

export function errorResponse(
  requestId: string,
  code: number,
  message: string,
  data?: Record<string, Object>
): BridgeResponse {
  const resp: BridgeResponse = {
    requestId: requestId,
    code: code,
    message: message,
    data: data
  }
  return resp
}
