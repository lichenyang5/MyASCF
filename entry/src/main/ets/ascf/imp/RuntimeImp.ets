export class RuntimeImp {
  ping(params?: Record<string, Object>): Record<string, Object> {
    console.info('[ASCF][RuntimeImp] ping')
    const emptyParams: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    const p: Record<string, Object> = params ?? emptyParams

    const result: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    result['text'] = 'pong from RuntimeImp'
    result['stage'] = 'RuntimeBiz -> RuntimeImp'
    result['receivedParams'] = p
    return result
  }

  echo(params?: Record<string, Object>): Record<string, Object> {
    console.info('[ASCF][RuntimeImp] echo')
    const emptyParams: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    const p: Record<string, Object> = params ?? emptyParams

    const result: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    result['echo'] = p
    result['stage'] = 'RuntimeBiz -> RuntimeImp'
    return result
  }
}
