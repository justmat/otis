-- speed table of speed tables
-- add your own!
--
--
-- add your scale name to the spds.names table, then define your scale below.
-- scales should be 6 entries long.

-- Ratio Table - Equal Temperament
-- 1.00000: Unison
-- 1.05946: minor 2nd
-- 1.12246: Major 2nd
-- 1.18920: minor 3rd
-- 1.25992: Major 3rd
-- 1.33484: Perfect 4th
-- 1.41421: Tritone
-- 1.49830: Perfect 5th
-- 1.58740: minor 6th
-- 1.68179: Major 6th
-- 1.78179: minor 7th
-- 1.88774: Major 7th
-- 2.00000: Octave
--
-- Multiply these numbers by 2, 4 or 8 for higher octaves, divide for lower octaves.

spds = {}

spds.names = {
  "free",
  "octaves",
  "fifths",
  "major"
}

spds.octaves = {
  0.125,
  0.250,
  0.500,
  1.000,
  2.000,
  4.000
}

spds.fifths = {
  0.500,
  0.750,
  1.000,
  1.500,
  2.000,
  3.000
}

spds.major = {
  1.12246,
  1.25992,
  1.33484,
  1.49830,
  1.68179,
  1.88774
}

return spds