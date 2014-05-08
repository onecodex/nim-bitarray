import bitarray
import murmur3
import strutils
import times
from math import random, randomize

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

{.push overflowChecks: off.}
proc hash(bf: TBloomFilter, item: string): seq[int] =
  var hashes: TMurmurHashes = murmur_hash(item, 0)
  newSeq(result, bf.n_hashes)
  for i in 0..(bf.n_hashes - 1):
    result[i] = abs(hashes[0] + hashes[1] * i) mod bf.n_bits
  return result
{.pop.}

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
  let n_tests = int(1e6)
  var bf = create_bloom_filter(n_elements = n_tests, n_bits_per_item = 12, n_hashes = 7)
  bf.insert("Here we go!")
  assert bf.lookup("Here we go!")
  assert (not bf.lookup("I'm not here."))

  let test_string_len = 50
  let sample_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  var k_test_elements = newSeq[string](n_tests)
  for i in 0..(n_tests - 1):
    var new_string = ""
    for j in 0..(test_string_len):
      new_string.add(sample_chars[random(51)])
    k_test_elements[i] = new_string

  let start_time = cpuTime()
  for i in 0..(n_tests - 1):
    bf.insert(k_test_elements[i])
  let end_time = cpuTime()
  echo("Took ", formatFloat(end_time - start_time, format = ffDecimal, precision = 4), " seconds to insert ", n_tests, " items.")

  let start_time_b = cpuTime()
  for i in 0..(n_tests - 1):
    doAssert bf.lookup(k_test_elements[i])
  let end_time_b = cpuTime()
  echo("Took ", formatFloat(end_time_b - start_time_b, format = ffDecimal, precision = 4), " seconds to lookup ", n_tests, " items.")
