import Foundation

enum ThreadsError: Error {
  case kernError(code: kern_return_t)
  case nilThreadsArray
}

internal func threadsCount() throws -> mach_msg_type_name_t {
  var count = mach_msg_type_number_t()

  var threads: thread_act_array_t? = nil

  let kern_return = task_threads(mach_task_self_, &threads, &count)

  guard kern_return == KERN_SUCCESS else {
    throw ThreadsError.kernError(code: kern_return)
  }

  guard let array = threads  else {
    throw ThreadsError.nilThreadsArray
  }

  let krsize = count * UInt32.init(MemoryLayout<thread_t>.size)
  let _ = vm_deallocate(mach_task_self_, vm_address_t(array.pointee), vm_size_t(krsize));

  return count
}
