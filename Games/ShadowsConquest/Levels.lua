-- Games/ShadowsConquest/Levels.lua

ArcadiaNexus.SC_Levels = {
    easy   = {},
    normal = {},
    hard   = {},
}

local L = ArcadiaNexus.SC_Levels

-- ============================================================
-- EINFACH (3×3) – 12 Puzzles
-- ============================================================
L.easy[1]  = { map = "110|101|011", optimalMoves = 4,  name = "Kreuz"      }
L.easy[2]  = { map = "111|000|111", optimalMoves = 3,  name = "Streifen"   }
L.easy[3]  = { map = "100|010|001", optimalMoves = 3,  name = "Diagonale"  }
L.easy[4]  = { map = "010|101|010", optimalMoves = 5,  name = "Gitter"     }
L.easy[5]  = { map = "111|111|111", optimalMoves = 5,  name = "Voll"       }
L.easy[6]  = { map = "100|100|100", optimalMoves = 3,  name = "Spalte"     }
L.easy[7]  = { map = "101|000|101", optimalMoves = 4,  name = "Ecken"      }
L.easy[8]  = { map = "110|110|000", optimalMoves = 3,  name = "Block"      }
L.easy[9]  = { map = "011|110|011", optimalMoves = 5,  name = "Wellen"     }
L.easy[10] = { map = "100|111|100", optimalMoves = 3,  name = "Plus"       }
L.easy[11] = { map = "101|111|101", optimalMoves = 6,  name = "Rahmen"     }
L.easy[12] = { map = "010|111|010", optimalMoves = 4,  name = "Pfeil"      }

-- ============================================================
-- NORMAL (5×5) – 12 Puzzles
-- ============================================================
L.normal[1]  = { map = "11011|10101|01110|10101|11011", optimalMoves = 8,  name = "Raute"       }
L.normal[2]  = { map = "11111|10001|10101|10001|11111", optimalMoves = 11, name = "Rahmen"      }
L.normal[3]  = { map = "10101|01010|10101|01010|10101", optimalMoves = 9,  name = "Schachbrett" }
L.normal[4]  = { map = "00100|01110|11111|01110|00100", optimalMoves = 7,  name = "Stern"       }
L.normal[5]  = { map = "11000|11000|00000|00011|00011", optimalMoves = 6,  name = "Diagonal"    }
L.normal[6]  = { map = "10001|01010|00100|01010|10001", optimalMoves = 8,  name = "X"           }
L.normal[7]  = { map = "11100|10100|11100|00100|00111", optimalMoves = 9,  name = "Z"           }
L.normal[8]  = { map = "01110|10001|10001|10001|01110", optimalMoves = 10, name = "Oval"        }
L.normal[9]  = { map = "11111|00000|11111|00000|11111", optimalMoves = 8,  name = "Linien"      }
L.normal[10] = { map = "10101|10101|11111|10101|10101", optimalMoves = 11, name = "Hash"        }
L.normal[11] = { map = "11011|11011|00000|11011|11011", optimalMoves = 9,  name = "Vier"        }
L.normal[12] = { map = "01010|10101|01010|10101|01010", optimalMoves = 13, name = "Punkte"      }

-- ============================================================
-- SCHWER (7×7) – 10 Puzzles
-- ============================================================
L.hard[1]  = { map = "1111111|1000001|1011101|1010101|1011101|1000001|1111111",
               optimalMoves = 15, name = "Labyrinth"  }
L.hard[2]  = { map = "1010101|0101010|1010101|0101010|1010101|0101010|1010101",
               optimalMoves = 16, name = "Schachbrett"}
L.hard[3]  = { map = "0001000|0011100|0111110|1111111|0111110|0011100|0001000",
               optimalMoves = 12, name = "Diamant"    }
L.hard[4]  = { map = "1111111|1000001|1000001|1000001|1000001|1000001|1111111",
               optimalMoves = 14, name = "Kasten"     }
L.hard[5]  = { map = "1000001|0100010|0010100|0001000|0010100|0100010|1000001",
               optimalMoves = 13, name = "Sanduhr"    }
L.hard[6]  = { map = "1100011|1100011|0000000|0010000|0000000|1100011|1100011",
               optimalMoves = 15, name = "Ecken"      }
L.hard[7]  = { map = "0111110|1000001|1011101|1010101|1011101|1000001|0111110",
               optimalMoves = 17, name = "Insel"      }
L.hard[8]  = { map = "1111111|0000000|1111111|0000000|1111111|0000000|1111111",
               optimalMoves = 14, name = "Streifen"   }
L.hard[9]  = { map = "1001001|0110110|1001001|0110110|1001001|0110110|1001001",
               optimalMoves = 18, name = "Gitter"     }
L.hard[10] = { map = "0010100|0111110|1111111|0111110|1111111|0111110|0010100",
               optimalMoves = 20, name = "Komplex"    }
