const TAG: string = 'AscfBridgeObject'

interface AscfRequest {
  requestId?: string
  action?: string
  params?: Record<string, Object>
  timeout?: number
}

interface AscfResponseData {
  action?: string
  stage?: string
}

interface AscfResponse {
  requestId: string
  code: number
  message: string
  data: AscfResponseData | Record<string, Object>
}

export class AscfBridgeObject {
  send(rawReq: string): string {
    console.info(`${TAG} send rawReq=${rawReq}`)

    let req: AscfRequest
    try {
      req = JSON.parse(rawReq) as AscfRequest
    } catch (e) {
      console.error(`${TAG} parse error: ${(e as Error).message}`)
      const errResp: AscfResponse = {
        requestId: '',
        code: 400,
        message: 'Invalid JSON',
        data: {}
      }
      return JSON.stringify(errResp)
    }

    const requestId: string = req.requestId ?? ''
    const action: string = req.action ?? ''
    console.info(`${TAG} parsed requestId=${requestId} action=${action}`)

    const resp: AscfResponse = {
      requestId: requestId,
      code: 0,
      message: 'ArkTS received request by JavaScriptProxy',
      data: {
        action: action,
        stage: 'H5 -> JavaScriptProxy -> ArkTS'
      }
    }
    return JSON.stringify(resp)
  }
}
