$Length = 15
$MustIncludeSets = 4

$CharacterSets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
                 "abcdefghijklmnopqrstuvwzyz",
                 "0123456789",
                 "!$%^&*-=_+#?"

$Random = New-Object Random

$Password = ""
$IncludedSets = ""
$IsNotComplex = $True
While ($IsNotComplex -Or $Password.Length -lt $Length) {
  $Set = $Random.Next(0, 4)

  If (!($IsNotComplex -And $IncludedSets -Match "$Set" -And $Password.Length -lt ($Length - $IncludedSets.Length))) {
    If ($IncludedSets -NotMatch "$Set") { $IncludedSets = "$IncludedSets$Set" }
    If ($IncludedSets.Length -ge $MustIncludeSets) { $IsNotcomplex = $False }

    $Password = "$Password$($CharacterSets[$Set].SubString($Random.Next(0, $CharacterSets[$Set].Length), 1))"
  }
}

$Password