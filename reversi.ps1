enum CELL_STATE{
  BLACK = 0
  WHITE = 1
  BLANK = 2
  WALL = 3
}

class Player{

  Player () {}

  [int] ChoseNext () {
    $userinput = Read-Host ">"
    $selected = $userinput -split " "
    $x = [int]$selected[0]
    $y = [int]$selected[1]
    return $x + $y * 10
  }
}

# Othelloのボード
# ボードのデータ構造の提供と、状態管理
class Board{
  # 10 * 10ますの正方形を1次元配列であらわす
  # 64ますでないのは、プレイエリアの範囲外(WALL)を表す領域があったほうが、
  # 石を裏返す処理が楽だから
  [array]$board

  Board () {
    $this.InitBoard()
  }

  [int] pos ($x,$y) {
    return $x + $y * 10
  }

  hidden InitBoard () {
    $this.board = @(0..99)
    for ($i = 0; $i -lt 100; $i++) {
      $this.board[$i] = [int][CELL_STATE]::WALL
    }

    for ($i = 1; $i -lt 9; $i++) {
      $rowfisrt = $i * 10 + 1
      for ($j = 0; $j -lt 8; $j++) {
        $this.board[$rowfisrt + $j] = [int][CELL_STATE]::BLANK
      }
    }

    $this.board[$this.pos(4,4)] = [int][CELL_STATE]::WHITE
    $this.board[$this.pos(5,4)] = [int][CELL_STATE]::BLACK
    $this.board[$this.pos(4,5)] = [int][CELL_STATE]::BLACK
    $this.board[$this.pos(5,5)] = [int][CELL_STATE]::WHITE
  }

  [int] Flip ([int]$pos,[int]$state) {
    $fl = $this.flipList($pos,$state)
    $flipCount = 0
    if ($fl.Length -gt 0) {
      $this.board[$pos] = $state
      foreach ($flip in $fl) {
        $this.board[$flip] = $state
        $flipCount++
      }
    }
    return $flipCount
  }


  [bool] CanPlaceStone ([int]$pos,[int]$state) {
    if ($this.board[$pos] -ne [int][CELL_STATE]::BLANK) {
      return $false
    }

    $fl = $this.flipList($pos,$state)
    if ($fl.Length -eq 0) {
      return $false
    } else {
      return $true
    }
  }

  [array] flipList ([int]$pos,[int]$state) {
    $flipList = @()
    $flipList += $this.lineFlipList($pos,$state,-10) # up direction
    $flipList += $this.lineFlipList($pos,$state,-9) # up right direction
    $flipList += $this.lineFlipList($pos,$state,1) # right direction
    $flipList += $this.lineFlipList($pos,$state,11) # down right direction
    $flipList += $this.lineFlipList($pos,$state,10) # down direction
    $flipList += $this.lineFlipList($pos,$state,9) # down left direction
    $flipList += $this.lineFlipList($pos,$state,-1) # left direction
    $flipList += $this.lineFlipList($pos,$state,-11) # up left direction
    return $flipList
  }

  [array] lineFlipList ([int]$pos,[int]$state,[int]$direction) {
    $flipList = @()
    $next = $pos
    while ($true) {
      $next += $direction
      if ($this.board[$next] -eq !($state)) {
        $flipList += $next
      } else {
        break
      }
    }

    if ($flipList.Length -gt 0 -and $this.board[$next] -eq $state) {
      return $flipList
    } else {
      return @() # empty list
    }
  }

  [array] GetBoard () {
    return $this.board
  }

  [array] BoardStatus () {
    $black = 0
    $white = 0
    foreach ($stone in $this.board) {
      if ($stone -eq 0) { $black++ }
      if ($stone -eq 1) { $white++ }
    }

    return $black,$white
  }
}

# ゲームの進行を行うクラス
class GameManager{
  [array]$players
  [Board]$board
  [int]$currentTurn
  [array]$STATE_DISPLAY = @(
    "●",# BLACK = 0
    "〇",# WHITE = 1
    "□",# BLANK = 2
    "☆"  # WALL = 3
  )

  GameManager ([Player]$player1,[Player]$player2) {
    $this.board = [Board]::new()
    $this.currentTurn = 0
    $this.players = @($player1,$player2)
  }

  StartGame () {
    $this.displayStart()
    $this.ManageGame()
  }

  # ゲームの管理
  # ボードの状態からゲームが終了常態かどうかを判定する
  # しゅうりょうじょうたいなら結果を表示して終了する
  # そうでなければ1手進める
  ManageGame () {
    while ($true) {
      # 黒番か白番か決定する
      $isDesicion = $this.desicionTurn()

      # どちらも打てない状況ならゲーム終了と判定して結果を表示して終わる
      if ($isDesicion -eq $false) {
        $this.displayEnd()
        return
      }

      # ゲームを1手進める
      $this.ProgressGame()
    }
  }

  # ゲームを1手進める
  ProgressGame () {
    $this.displayCurrentBoard()
		$this.displayCurrentStatus()
    $nextpos = $this.nextStonePos()
    $this.board.Flip($nextpos,$this.currentTurn)
    $this.currentTurn = !($this.currentTurn)
  }

  [int] nextStonePos () {
    $this.displayPlaceStone()
    $pos = $this.players[$this.currentTurn].ChoseNext()
    while ($this.board.CanPlaceStone($pos,$this.currentTurn) -eq $false) {
      $this.displayCannotPlace()
      $pos = $this.players[$this.currentTurn].ChoseNext()
    }
    return $pos
  }

  # 手番を決める
  # 決まった場合はTrue、決められない場合はFalseをかえす
  [bool] desicionTurn () {
    # 現在の手番で打てる場所があるか探す
    if ($this.canPlace($this.currentTurn)) {
      return $true
    }

    # バスが起きた場合か、ゲーム終了の場合以下が実行される
    if ($this.canPlace(!($this.currentTurn))) {
      $this.currentTurn = !($this.currentTurn)
      return $true
    }

    # 黒番白番ともに打てる場所がない
    return $false
  }

  # 黒番白番どちらかが打てるかどうかを判定する
  [bool] canPlace ([int]$color) {
    foreach ($i in @(0..$this.board.GetBoard().Length)) {
      if ($this.board.CanPlaceStone($i,$color)) {
        return $true
      }
    }
    return $false
  }

  displayStart () {
    Write-Host "ゲームスタートです！"
  }

  displayEnd () {
    Write-Host "ゲームおわりです。"
  }

  displayPlaceStone () {
    Write-Host $this.STATE_DISPLAY[$this.currentTurn] "の番です。"
    Write-Host "打つ場所を選んでください。"
  }

  displayCannotPlace () {
    Write-Host "そこには打てません。"
  }

  displayCurrentBoard () {
    Clear-Host
    $cur_board = $this.board.GetBoard()
    for ($i = 0; $i -lt 100; $i++) {
      Write-Host $this.STATE_DISPLAY[$cur_board[$i]] -NoNewline

      # ボードの右端まで来たら改行
      if ($i % 10 -eq 9) {
        Write-Host ""
      }
    }
  }

	displayCurrentStatus () {
    $board_status = $this.board.BoardStatus()
    $black = $board_status[0]
    $white = $board_status[1]
    Write-Host "現在の状況は●：$black  〇:$white"
	}
}


$p1 = [Player]::new()
$p2 = [Player]::new()
$gm = [GameManager]::new($p1,$p2)
$gm.StartGame()
