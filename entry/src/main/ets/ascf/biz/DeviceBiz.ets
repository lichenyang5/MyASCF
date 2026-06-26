import { BridgeRequest } from '../protocol/BridgeRequest'
import { BridgeResponse, successResponse } from '../protocol/BridgeResponse'
import { DeviceImp } from '../imp/DeviceImp'

export class DeviceBiz {
  private readonly imp: DeviceImp

  constructor(imp: DeviceImp) {
    this.imp = imp
  }

  getInfo(request: BridgeRequest): BridgeResponse {
    console.info('[ASCF][DeviceBiz] getInfo')
    const impResult: Record<string, Object> = this.imp.getInfo(request.params)

    const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    data['action'] = request.action
    data['stage'] = 'DeviceBiz -> DeviceImp'
    data['result'] = impResult

    return successResponse(request.requestId, 'device.getInfo success from Biz', data)
  }
}
