# from memfiles import nil
from strutils import `%`
import unsigned

# Type declarations
type
  TBitScalar = int

type
  EBitarray = object of EBase
  TBitarray = object
    bitarray: seq[TBitScalar]
    size_elements: int
    size_bits: int
    size_specified: int


proc create_bitarray(size: int): TBitarray =
  ## Creates a bitarray using a specified input size.
  ## Note that this will round up to the nearest byte
  let n_elements = size div (sizeof(TBitScalar) * 8)
  let n_bits = n_elements * (sizeof(TBitScalar) * 8)
  result = TBitarray(bitarray: newSeq[TBitScalar](n_elements),
                     size_elements: n_elements, size_bits: n_bits,
                     size_specified: size)


proc `[]=`*(ba: var TBitarray, index: int, val: bool) {.inline.} =
  ## Sets the bit at an index to be either 0 (false) or 1 (true)
  let i_element = index div (sizeof(TBitScalar) * 8)
  let i_offset = index mod (sizeof(TBitScalar) * 8)
  # echo("Inserting $1 at position $2." % (index, int(val)))
  if val:
    ba.bitarray[i_element] = (ba.bitarray[i_element] or (0b1 shl i_offset))
  else:
    ba.bitarray[i_element] = (ba.bitarray[i_element] and ((not 0b1) shl i_offset))


proc `[]`*(ba: var TBitarray, index: int): bool {.inline.} =
  ## Gets the bit at an index element (returns a bool)
  let i_element = index div (sizeof(TBitScalar) * 8)
  let i_offset = index mod (sizeof(TBitScalar) * 8)
  result = bool((ba.bitarray[i_element] shr i_offset) and 1)


proc `$`(ba: TBitarray): string =
  ## Print the number of bits and elements in the bitarray (elements are currently defined as 8-bit chars)
  result = ("Bitarray with $1 bits and $2 unique elements." %
            [$ba.size_bits, $ba.size_elements])


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
  echo 0b1
  echo 0b10
  echo 0b100
  echo 0b1000
  echo 0b10000
  echo 0b100000
  echo 0b1000000
  echo 0b10000000
  echo 0b11111111

  type
    TCharArray = array[0..5, char]

  var tc: TCharArray
  tc = ['A', 'B', 'C', 'D', 'E', 'F']
  echo tc

  echo bitarray[0]
  echo bitarray[1]
  echo bitarray[2]
  echo bitarray[3]
