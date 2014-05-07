import private/memfiles
from os import nil
from strutils import `%`, formatFloat, ffDecimal, toBin
import unsigned
from math import random, randomize
from times import nil


# Type declarations
type
  BitScalar* = int

type
  EBitarray = object of EBase
  BitarrayKind = enum inmem, mmap
  FlexArray {.unchecked.} = array[0..0, BitScalar]
  Bitarray* = ref object
    size_elements: int
    size_bits*: int
    size_specified*: int
    bitarray: ptr FlexArray
    case kind: BitarrayKind
    of inmem:
      nil
    of mmap:
      mm_filehandle: TMemFile


const ONE = BitScalar(1)


proc finalize_bitarray(a: Bitarray) =
  if not a.bitarray.isNil:
    case a.kind
    of inmem:
      dealloc(a.bitarray)
      a.bitarray = nil
    of mmap:
      a.mm_filehandle.close()


proc create_bitarray*(size: int): Bitarray =
  ## Creates an in-memory bitarray using a specified input size.
  ## Note that this will round up to the nearest byte.
  let n_elements = size div (sizeof(BitScalar) * 8)
  let n_bits = n_elements * (sizeof(BitScalar) * 8)
  new(result, finalize_bitarray)
  result.kind = inmem
  result.bitarray = cast[ptr FlexArray](alloc0(n_elements * sizeof(BitScalar)))
  result.size_elements = n_elements
  result.size_bits = n_bits
  result.size_specified = size


proc create_bitarray*(file: string, size: int = -1): Bitarray =
  ## Creates an mmap-backed bitarray. If the specified file exists
  ## it will be opened, but an exception will be raised if the size
  ## is specified and does not match. If the file does not exist
  ## it will be created.
  let n_elements = size div (sizeof(char) * 8)
  let n_bits = n_elements * (sizeof(char) * 8)
  var mm_file: TMemFile
  if os.existsFile(file):
    mm_file = open(file, mode = fmReadWrite, mappedSize = -1)
    if size != -1 and mm_file.size != n_elements:
      raise newException(EBitarray, "Existing mmap file does not have the specified size $1" % $size)
  else:
    if size == -1:
      raise newException(EBitarray, "No existing mmap file. Must specify size to create one.")
    mm_file = open(file, mode = fmReadWrite, newFileSize = n_elements)

  new(result, finalize_bitarray)
  result.kind = mmap
  result.bitarray = cast[ptr FlexArray](mm_file.mem)
  result.size_elements = n_elements
  result.size_bits = n_bits
  result.size_specified = size
  result.mm_filehandle = mm_file


proc `[]=`*(ba: var Bitarray, index: int, val: bool) {.inline.} =
  ## Sets the bit at an index to be either 0 (false) or 1 (true)
  if index >= ba.size_bits or index < 0:
    raise newException(EBitarray, "Specified index is too large.")
  let i_element = index div (sizeof(BitScalar) * 8)
  let i_offset = index mod (sizeof(BitScalar) * 8)
  if val:
    ba.bitarray[i_element] = (ba.bitarray[i_element] or (ONE shl i_offset))
  else:
    ba.bitarray[i_element] = (ba.bitarray[i_element] and ((not ONE) shl i_offset))


proc `[]`*(ba: var Bitarray, index: int): bool {.inline.} =
  ## Gets the bit at an index element (returns a bool)
  if index >= ba.size_bits or index < 0:
    raise newException(EBitarray, "Specified index is too large.")
  let i_element = index div (sizeof(BitScalar) * 8)
  let i_offset = index mod (sizeof(BitScalar) * 8)
  result = bool((ba.bitarray[i_element] shr i_offset) and ONE)


proc `[]`*(ba: var Bitarray, index: TSlice): BitScalar {.inline.} =
  ## Get the bits for a slice of the bitarray. Supports slice sizes
  ## up the maximum element size (64 bits by default)
  if index.b >= ba.size_bits or index.a < 0:
    raise newException(EBitarray, "Specified index is too large.")
  if (index.b - index.a) > (sizeof(BitScalar) * 8):
    raise newException(EBitarray, "Only slices up to $1 bits are supported." % $(sizeof(BitScalar) * 8))

  let i_element_a = index.a div (sizeof(BitScalar) * 8)
  let i_offset_a = index.a mod (sizeof(BitScalar) * 8)
  let i_element_b = index.b div (sizeof(BitScalar) * 8)
  let i_offset_b = sizeof(BitScalar) * 8 - i_offset_a
  var result = ba.bitarray[i_element_a] shr i_offset_a
  if i_element_a != i_element_b:  # Combine two slices
    let slice_b = ba.bitarray[i_element_b] shl i_offset_b
    result = result or slice_b
  return result  # Fails if this isn't included?


proc `[]=`*(ba: var Bitarray, index: TSlice, val: BitScalar) {.inline.} =
  ## Set the bits for a slice of the bitarray. Supports slice sizes
  ## up to the maximum element size (64 bits by default)
  ## Note: This inserts using a bitwise-or, it will *not* overwrite previously
  ## set true values!
  if index.b >= ba.size_bits or index.a < 0:
    raise newException(EBitarray, "Specified index is too large.")
  if (index.b - index.a) > (sizeof(BitScalar) * 8):
    raise newException(EBitarray, "Only slices up to $1 bits are supported." % $(sizeof(BitScalar) * 8))

  # TODO(nbg): Make a macro for handling this and also the if/else in-memory piece
  let i_element_a = index.a div (sizeof(BitScalar) * 8)
  let i_offset_a = index.a mod (sizeof(BitScalar) * 8)
  let i_element_b = index.b div (sizeof(BitScalar) * 8)
  let i_offset_b = sizeof(BitScalar) * 8 - i_offset_a

  let insert_a = val shl i_offset_a
  ba.bitarray[i_element_a] = ba.bitarray[i_element_a] or insert_a
  if i_element_a != i_element_b:
    let insert_b = val shr i_offset_b
    ba.bitarray[i_element_b] = ba.bitarray[i_element_b] or insert_b


proc `$`*(ba: Bitarray): string =
  ## Print the number of bits and elements in the bitarray (elements are currently defined as 8-bit chars)
  result = ("Bitarray with $1 bits and $2 unique elements. In-memory?: $3." %
            [$ba.size_bits, $ba.size_elements, $ba.kind])


when isMainModule:
  echo("Testing bitarray.nim code.")
  let n_tests: int = int(1e6)
  let n_bits: int = int(2e9)  # ~240MB, i.e., much larger than L3 cache

  var ba = create_bitarray(n_bits)
  echo "Created a bitarray."
  echo ba
  ba[0] = true
  echo ba.bitarray[0..10]
  ba[1] = true
  echo ba.bitarray[0..10]
  ba[2] = true
  echo ba.bitarray[0..10]

  var bab = create_bitarray("/tmp/ba.mmap", size=n_bits)
  echo bab.bitarray[0]
  echo bab.bitarray[1]
  echo bab.bitarray[2]
  echo bab.bitarray[3]
  bab.bitarray[3] = 4
  echo bab.bitarray[3]

  # Test range lookups/inserts
  ba[65] = true
  assert ba[65]
  echo "Res is: ", ba[2..66], " binary: ", toBin(ba[2..66], 64)
  assert ba[2..66] == -9223372036854775807
  ba[131] = true
  ba[194] = true
  assert ba[2..66] == ba[131..194]
  let slice_value = ba[131..194]
  ba[270..333] = slice_value
  ba[400..463] = BitScalar(-9223372036854775807)
  assert ba[131..194] == ba[270..333]
  assert ba[131..194] == ba[400..463]
  echo ba.bitarray[0..10]

  # Seed RNG
  randomize(2882)  # Seed the RNG
  var n_test_positions = newSeq[int](n_tests)

  for i in 0..(n_tests - 1):
    n_test_positions[i] = random(n_bits)

  # Timing tests
  var start_time, end_time: float
  start_time = times.cpuTime()
  for i in 0..(n_tests - 1):
    ba[n_test_positions[i]] = true
  end_time = times.cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to insert ", n_tests, " items (in-memory).")

  start_time = times.cpuTime()
  for i in 0..(n_tests - 1):
    bab[n_test_positions[i]] = true
  end_time = times.cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to insert ", n_tests, " items (mmap-backed).")

  var bit_value: bool
  start_time = times.cpuTime()
  for i in 0..(n_tests - 1):
    doAssert ba[n_test_positions[i]]
  end_time = times.cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to lookup ", n_tests, " items (in-memory).")

  start_time = times.cpuTime()
  for i in 0..(n_tests - 1):
    doAssert bab[n_test_positions[i]]
  end_time = times.cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to lookup ", n_tests, " items (mmap-backed).")

