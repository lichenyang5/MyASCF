import { pasteboard } from '@kit.BasicServicesKit'

export class ClipboardImp {
  async writeText(text: string): Promise<Record<string, Object>> {
    console.info('[ASCF][ClipboardImp] writeText start')
    try {
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      const pasteData: pasteboard.PasteData =
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text)
      await systemPasteboard.setData(pasteData)
      console.info('[ASCF][ClipboardImp] writeText success')

      const result: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      result['stage'] = 'ClipboardBiz -> ClipboardImp -> OpenHarmony pasteboard'
      result['api'] = 'pasteboard'
      result['writtenText'] = text
      result['note'] = 'This data comes from OpenHarmony system pasteboard API'
      return result
    } catch (e) {
      const errMsg: string = (e as Error).message
      console.error(`[ASCF][ClipboardImp] writeText error: ${errMsg}`)
      throw new Error(`pasteboard.setData failed: ${errMsg}`)
    }
  }

  async readText(): Promise<Record<string, Object>> {
    console.info('[ASCF][ClipboardImp] readText start')
    try {
      const systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
      const pasteData: pasteboard.PasteData = await systemPasteboard.getData()
      const text: string = pasteData.getPrimaryText()
      console.info('[ASCF][ClipboardImp] readText success')

      const result: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
      result['stage'] = 'ClipboardBiz -> ClipboardImp -> OpenHarmony pasteboard'
      result['api'] = 'pasteboard'
      result['text'] = text
      result['note'] = 'This data comes from OpenHarmony system pasteboard API'
      return result
    } catch (e) {
      const errMsg: string = (e as Error).message
      console.error(`[ASCF][ClipboardImp] readText error: ${errMsg}`)
      throw new Error(`pasteboard.getData failed: ${errMsg}`)
    }
  }
}
