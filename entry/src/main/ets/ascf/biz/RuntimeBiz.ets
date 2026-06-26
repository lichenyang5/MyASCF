import { BridgeRequest } from '../protocol/BridgeRequest'
import { BridgeResponse, successResponse } from '../protocol/BridgeResponse'
import { RuntimeImp } from '../imp/RuntimeImp'

export class RuntimeBiz {
  private readonly imp: RuntimeImp

  constructor(imp: RuntimeImp) {
    this.imp = imp
  }

  ping(request: BridgeRequest): BridgeResponse {
    console.info('[ASCF][RuntimeBiz] ping')
    const impResult: Record<string, Object> = this.imp.ping(request.params)

    const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    data['action'] = request.action
    data['stage'] = 'RuntimeBiz -> RuntimeImp'
    data['result'] = impResult

    return successResponse(request.requestId, 'runtime.ping success from Biz', data)
  }

  echo(request: BridgeRequest): BridgeResponse {
    console.info('[ASCF][RuntimeBiz] echo')
    const impResult: Record<string, Object> = this.imp.echo(request.params)

    const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    data['action'] = request.action
    data['stage'] = 'RuntimeBiz -> RuntimeImp'
    data['result'] = impResult

    return successResponse(request.requestId, 'runtime.echo success from Biz', data)
  }
}
