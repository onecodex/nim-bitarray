#from memfiles import nil  # Not in love with this as it doesn't jive with method syntax, i.e., need to call memfiles.close(mm) vs. mm.close()
import private/memfiles
from os import nil
from strutils import `%`
import unsigned
import baseutils  # Pointer arithmetic

# Type declarations
type
  TBitScalar = int

type
  EBitarray = object of EBase
  TBitarrayKind = enum inmem, mmap
  PBitarray = ref TBitarray
  TFlexArray {.unchecked.} = array[0..0, TBitScalar]
  TBitarray = object
    size_elements: int
    size_bits: int
    size_specified: int
    case in_memory: bool
    of true:
      bitarray: seq[TBitScalar]
    of false:
      bitarray_mmap: ptr TFlexArray



proc create_bitarray(size: int): TBitarray =
  ## Creates an in-memory bitarray using a specified input size.
  ## Note that this will round up to the nearest byte.
  let n_elements = size div (sizeof(TBitScalar) * 8)
  let n_bits = n_elements * (sizeof(TBitScalar) * 8)
  result = TBitarray(in_memory: true, bitarray: newSeq[TBitScalar](n_elements),
                     size_elements: n_elements, size_bits: n_bits,
                     size_specified: size)


proc create_bitarray(file: string, size: int = -1): TBitarray =
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

  result = TBitarray(in_memory: false,
                     bitarray_mmap: cast[ptr TFlexArray](mm_file.mem),
                     size_elements: n_elements, size_bits: n_bits,
                     size_specified: size)


proc `[]=`*(ba: var TBitarray, index: int, val: bool) {.inline.} =
  ## Sets the bit at an index to be either 0 (false) or 1 (true)
  let i_element = index div (sizeof(TBitScalar) * 8)
  let i_offset = index mod (sizeof(TBitScalar) * 8)
  if ba.in_memory:
    if val:
      ba.bitarray[i_element] = (ba.bitarray[i_element] or (0b1 shl i_offset))
    else:
      ba.bitarray[i_element] = (ba.bitarray[i_element] and ((not 0b1) shl i_offset))
  else:
    if val:
      ba.bitarray_mmap[i_element] = (ba.bitarray_mmap[i_element] or (0b1 shl i_offset))
    else:
      ba.bitarray_mmap[i_element] = (ba.bitarray_mmap[i_element] and ((not 0b1) shl i_offset))


proc `[]`*(ba: var TBitarray, index: int): bool {.inline.} =
  ## Gets the bit at an index element (returns a bool)
  let i_element = index div (sizeof(TBitScalar) * 8)
  let i_offset = index mod (sizeof(TBitScalar) * 8)
  if ba.in_memory:
    result = bool((ba.bitarray[i_element] shr i_offset) and 1)
  else:
    result = bool((ba.bitarray_mmap[i_element] shr i_offset) and 1)

proc `$`(ba: TBitarray): string =
  ## Print the number of bits and elements in the bitarray (elements are currently defined as 8-bit chars)
  result = ("Bitarray with $1 bits and $2 unique elements. In-memory?: $3." %
            [$ba.size_bits, $ba.size_elements, $ba.in_memory])


when isMainModule:
  echo("Testing bitarray.nim code.")
  var bitarray = create_bitarray(int(1e8))
  echo "Created a bitarray."
  echo bitarray
  bitarray[0] = true
  echo bitarray.bitarray[0..10]
  bitarray[1] = true
  echo bitarray.bitarray[0..10]
  bitarray[2] = true
  echo bitarray.bitarray[0..10]

  var bitarray_b = create_bitarray("/tmp/ba.mmap", size=1024 * 8)
  echo bitarray_b.bitarray_mmap[0]
  echo bitarray_b.bitarray_mmap[1]
  echo bitarray_b.bitarray_mmap[2]
  echo bitarray_b.bitarray_mmap[3]
  bitarray_b.bitarray_mmap[3] = 4
  echo bitarray_b.bitarray_mmap[3]
