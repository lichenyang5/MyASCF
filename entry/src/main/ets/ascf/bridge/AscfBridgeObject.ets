interface BridgeParams {
  from?: string
  message?: string
}

interface BridgeRequest {
  requestId?: string
  action?: string
  params?: BridgeParams
  timeout?: number
}

interface BridgeResponseData {
  action?: string
  stage?: string
  receivedParams?: BridgeParams
}

interface BridgeResponse {
  requestId: string
  code: number
  message: string
  data: BridgeResponseData
}

export type AscfCallbackToH5 = (responseJson: string) => void

export class AscfBridgeObject {
  private readonly callbackToH5: AscfCallbackToH5

  constructor(callbackToH5: AscfCallbackToH5) {
    this.callbackToH5 = callbackToH5
  }

  send(rawReq: string): string {
    console.info(`[ASCF][Bridge] send rawReq = ${rawReq}`)

    let responseJson: string
    try {
      const req: BridgeRequest = JSON.parse(rawReq) as BridgeRequest
      const requestId: string = req.requestId ?? ''
      const action: string = req.action ?? ''
      const emptyParams: BridgeParams = {}
      const params: BridgeParams = req.params ?? emptyParams

      const data: BridgeResponseData = {
        action: action,
        stage: 'H5 -> JavaScriptProxy -> ArkTS -> runJavaScript -> H5',
        receivedParams: params
      }
      const response: BridgeResponse = {
        requestId: requestId,
        code: 0,
        message: 'ArkTS callback by runJavaScript',
        data: data
      }
      responseJson = JSON.stringify(response)
    } catch (e) {
      console.error(`[ASCF][Bridge] parse error: ${(e as Error).message}`)
      const errData: BridgeResponseData = {}
      const errResp: BridgeResponse = {
        requestId: '',
        code: 400,
        message: 'Invalid JSON',
        data: errData
      }
      responseJson = JSON.stringify(errResp)
    }

    console.info(`[ASCF][Bridge] callbackToH5 response = ${responseJson}`)
    this.callbackToH5(responseJson)
    return ''
  }
}
