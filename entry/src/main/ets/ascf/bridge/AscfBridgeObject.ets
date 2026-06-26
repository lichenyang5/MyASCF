import { BridgeController } from '../controller/BridgeController'

export class AscfBridgeObject {
  private readonly controller: BridgeController

  constructor(controller: BridgeController) {
    this.controller = controller
  }

  send(rawReq: string): void {
    console.info(`[ASCF][Bridge] JavaScriptProxy send rawReq = ${rawReq}`)
    this.controller.handle(rawReq).catch((e: Error) => {
      console.error(`[ASCF][Bridge] unhandled handle error: ${e.message}`)
    })
  }
}
