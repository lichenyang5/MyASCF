import { add as napiAdd, getNativeVersion as napiGetVersion } from 'libentry.so'

export class NativeImp {
  addByNapi(a: number, b: number): Record<string, Object> {
    console.info('[ASCF][NativeImp] addByNapi start')
    const result: number = napiAdd(a, b)
    console.info(`[ASCF][NativeImp] addByNapi result = ${result}`)

    const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    data['result'] = result
    data['a'] = a
    data['b'] = b
    data['stage'] = 'NativeBiz -> NativeImp -> NAPI -> C++'
    data['api'] = 'Node-API / NAPI'
    data['note'] = 'This result comes from C++ native module'
    return data
  }

  getNativeVersion(): Record<string, Object> {
    console.info('[ASCF][NativeImp] getNativeVersion start')
    const version: string = napiGetVersion()
    console.info(`[ASCF][NativeImp] getNativeVersion result = ${version}`)

    const data: Record<string, Object> = JSON.parse('{}') as Record<string, Object>
    data['version'] = version
    data['stage'] = 'NativeBiz -> NativeImp -> NAPI -> C++'
    data['api'] = 'Node-API / NAPI'
    data['note'] = 'This version comes from C++ native module'
    return data
  }
}
