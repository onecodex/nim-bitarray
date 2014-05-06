import bitarray
import hashes
import strutils

type
  TBloomFilter = object
    bitarray: TBitarray
    n_hashes: int
    n_bits_per_item: int
    n_bits: int

proc create_bloom_filter*(n_elements: int, n_bits_per_item: int = 12, n_hashes: int = 6): TBloomFilter =
  ## Generate a Bloom filter, yay so simple!
  let n_bits = n_elements * n_bits_per_item
  result = TBloomFilter(
      bitarray: create_bitarray(n_bits),
      n_hashes: n_hashes,
      n_bits_per_item: n_bits_per_item,
      n_bits: n_bits
    )

proc hash(bf: TBloomFilter, item: string): seq[int] =
  newSeq(result, bf.n_hashes)
  for i in 0..(bf.n_hashes - 1):
    result[i] = abs(hash(item & "_" & intToStr(i))) mod bf.n_bits
  return result

proc insert*(bf: var TBloomFilter, item: string) =
  ## Put the string there
  let hashes = hash(bf, item)
  for h in hashes:
    bf.bitarray[h] = true

proc lookup*(bf: var TBloomFilter, item: string): bool =
  ## Is the string there?
  let hashes = hash(bf, item)
  result = true
  for h in hashes:
    result = result and bf.bitarray[h]
  return result


when isMainModule:
  echo "Quick working Bloom filter example."
  var bf = create_bloom_filter(n_elements = int(1e6), n_bits_per_item = 12, n_hashes = 7)
  bf.insert("Here we go!")
  assert bf.lookup("Here we go!")
  assert (not bf.lookup("I'm not here."))