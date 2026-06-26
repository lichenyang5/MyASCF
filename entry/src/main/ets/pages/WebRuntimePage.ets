import webview from '@ohos.web.webview'
import { AscfBridgeObject } from '../ascf/bridge/AscfBridgeObject'
import { BridgeController } from '../ascf/controller/BridgeController'
import { BridgeDispatcher } from '../ascf/dispatcher/BridgeDispatcher'
import { HandlerRegister } from '../ascf/register/HandlerRegister'

@Component
export struct WebRuntimePage {
  private controller: webview.WebviewController = new webview.WebviewController()
  private register: HandlerRegister = new HandlerRegister()
  private dispatcher: BridgeDispatcher = new BridgeDispatcher(this.register)
  private bridgeController: BridgeController = new BridgeController(
    (responseJson: string): void => {
      this.handleBridgeCallback(responseJson)
    },
    this.dispatcher
  )
  private bridge: AscfBridgeObject = new AscfBridgeObject(this.bridgeController)

  private handleBridgeCallback(responseJson: string): void {
    const script: string = `window.__ascfResolve(${responseJson})`
    console.info(`[ASCF][WebRuntimePage] runJavaScript: ${script}`)
    try {
      this.controller.runJavaScript(script)
    } catch (e) {
      console.error(`[ASCF][WebRuntimePage] runJavaScript error: ${(e as Error).message}`)
    }
  }

  build() {
    Column() {
      Web({
        src: $rawfile('h5/index.html'),
        controller: this.controller
      })
        .width('100%')
        .height('100%')
        .javaScriptAccess(true)
        .javaScriptProxy({
          object: this.bridge,
          name: 'ascfBridge',
          methodList: ['send'],
          controller: this.controller
        })
        .onPageBegin((event) => {
          console.info(`[ASCF][WebRuntimePage] onPageBegin url=${event?.url ?? ''}`)
        })
        .onPageEnd((event) => {
          console.info(`[ASCF][WebRuntimePage] onPageEnd url=${event?.url ?? ''}`)
        })
    }
    .width('100%')
    .height('100%')
  }
}
