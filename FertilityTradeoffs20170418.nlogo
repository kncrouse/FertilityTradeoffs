breed [ households household ]
breed [ humans human ]

households-own [
  parent1
  parent2
  child
  funds
  cells ; PATCHES of this household
]

humans-own [
  adult? ; adult or child
  generation
  age
  house ; HOUSEHOLD
  current-education ; current education level
  desired-education ; desired education level
  child-count ; total offspring produced
]

patches-own [
  phouse
  bidder
  current-bid
  previous-bid
]

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: SETUP ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to setup
  clear-all
  setup-patches
  setup-humans
  ask households [ update-household ]
  reset-ticks
end

to setup-patches
  ask patches [
    set pcolor black
    set phouse nobody
    set bidder nobody
    set current-bid 0
    set previous-bid 0
  ]
end

to setup-humans
  create-humans ( count patches * 0.5 ) [
    initialize-human
  ]
end

to initialize-human
  set adult? true
  set age 0
  set hidden? false
  set size 1
  set shape "person"
  set current-education 0
  set desired-education random 5
  set child-count 0
  set generation 0
  ;set color one-of base-colors + random 3 - random 3
  move-to one-of patches with [ count humans-here = 0 ]
  set current-education desired-education
  setup-new-house
end

to initialize-human-with-parents [ p1 p2 ]
  set adult? false
  set hidden? false
  set size 0.7
  set shape "person"
  set current-education 0
  set child-count 0
  set age 0
  ;set color ifelse-value ( random-float 1.0 < 0.5 ) [ [color] of p1 ] [ [color] of p2]
  set generation [generation] of p1 + 1
  ask p1 [ set child-count child-count + 1 ]
  ask p2 [ set child-count child-count + 1 ]
  set desired-education ( [desired-education] of p1 + [desired-education] of p2 ) / 2
  if random-float 1.0 < education-mutation-rate [ set desired-education desired-education - random 10 + random 10 ]
end

to setup-new-house
  hatch-households 1 [
    set parent1 nobody
    set parent2 nobody
    set child nobody
    set cells nobody
    set funds 0
    ask patch-here [ set phouse myself ]
    set hidden? true
    set color one-of base-colors + random 4 - random 2
    set label-color one-of base-colors + random 4 - random 2
    ask myself [ set house myself ]
  ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go

  ask households [ earn-funds ]
  ask households [ invest-in-reproduction  ]
  ask patches with [ bidder != nobody and count humans-here = 0 and phouse = nobody ] [ ask bidder [ add-cell myself ] ]
  ask humans with [ adult? ] [ if random-float 1.0 < adult-mortality-rate [ make-dead ]]
  ask humans with [ not adult? ] [ if random-float 1.0 < child-mortality-rate [ make-dead ]]
  ask households [ update-household ]
  ask humans with [ house = nobody ] [ make-dead ]
  ask patches with [ phouse = nobody ] [ set pcolor black ]
  ask humans [ set age age + 1 ]
  tick
end

to make-dead
  let h house
  ask patch-here [ set phouse nobody ]
  die
  ask h [ update-household ]
end

;:::: HOUSEHOLDS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to update-household
  set cells patches with [ phouse = myself ]
  set parent1 one-of humans with [ adult? and house = myself ]
  set parent2 one-of humans with [ adult? and house = myself and self != [parent1] of house ]
  set child one-of humans with [ not adult? and house = myself ]
  ask cells [ set pcolor [color] of myself ]
  if parent1 != nobody [ ask parent1 [ set color [label-color] of myself - 3 ]]
  if parent2 != nobody [ ask parent2 [ set color [label-color] of myself - 3 ]]
  if child != nobody [ ask child [ set color [label-color] of myself - 2 ]]
  if parent1 = nobody and parent2 = nobody [
    kick-out-child
    household-make-dead ]
end

to earn-funds
  let money1 ifelse-value ( parent1 != nobody ) [ income-rate * ( 1 + [current-education] of parent1 ) ] [ 0 ]
  let money2 ifelse-value ( parent2 != nobody ) [ income-rate * ( 1 + [current-education] of parent2 ) ] [ 0 ]
  set funds funds + money1 + money2
end

to invest-in-reproduction
  ifelse child != nobody
    [ invest-in-child ]
    [ ifelse parent1 != nobody and parent2 != nobody
      [ make-child ]
      [ find-spouse ]]
end

to-report has-empty-cells update-household report ( count cells with [ count humans-here = 0 ] > 0 ) end ;;
to-report child-has-matured report [current-education] of child >= [desired-education] of child end

to find-spouse
  ifelse has-empty-cells
  [ let other-house one-of other households with [ parent1 = nobody or parent2 = nobody ]
    if other-house != nobody [ combine-household-with other-house ]]
  [ increase-property ]
end

to invest-in-child
  repeat floor ( funds / education-cost ) [
    ask child [ set current-education current-education + 1 ]
    set funds funds - education-cost
    if ( [current-education] of child >= [desired-education] of child ) [ kick-out-child stop ]
  ]
end

to increase-property
  let current-funds funds
  let best-cell nobody
  let lowest-bid 1000000
  ask cells
  [ ask neighbors4 with [ count humans-here = 0 and phouse = nobody ]
    [ if ( current-funds > current-bid and current-bid < lowest-bid )
      [ set best-cell self set lowest-bid current-bid ]]]
  if best-cell != nobody
  [ ask best-cell [
    set current-bid current-funds
    set bidder myself ]]
end

to add-cell [ cell ]
  ask cell [
    set phouse myself
    set previous-bid [funds] of myself
    set bidder nobody
    set current-bid 0 ]
  set funds 0
end

to kick-out-child
  if child != nobody [
    ask child [
      set adult? true
      set size 1.0
      setup-new-house
    ]]
end

to make-child
  if parent1 != nobody and parent2 != nobody [
    ifelse has-empty-cells
      [ hatch-humans 1
        [ initialize-human-with-parents [parent1] of myself [parent2] of myself
          set house myself
          ask house [ ifelse has-empty-cells
            [ ask myself [ move-to one-of patches with [ count humans-here = 0 and phouse = [house] of myself ]]] [ ask myself [ die ] ]]]] ;;
      [ increase-property ]
  ]
end

to household-make-dead
  if cells != nobody [
    ask cells [
      set pcolor black
      set phouse nobody ]]
  ask patches with [ bidder = myself ] [ set bidder nobody ]
  die
end

to combine-household-with [ other-house ]
  let open-cell one-of cells with [ count humans-here = 0 ]
  if open-cell != nobody [
    if [parent1] of other-house != nobody [ ask [parent1] of other-house [ move-to open-cell set house myself ]]
    if [parent2] of other-house != nobody [ ask [parent2] of other-house [ move-to open-cell set house myself ]]
    set funds funds + [funds] of other-house
    ask other-house [ household-make-dead ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
206
10
664
469
-1
-1
28.13
1
10
1
1
1
0
1
1
1
0
15
0
15
1
1
1
ticks
30.0

BUTTON
112
21
175
54
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
38
21
104
54
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
148
195
181
income-rate
income-rate
1
10
3.24
0.01
1
NIL
HORIZONTAL

PLOT
681
10
995
222
Economy over Time
Time
Money
0.0
5.0
0.0
1.0
true
true
"" ""
PENS
"real estate" 1.0 0 -13840069 true "" "plot mean [previous-bid] of patches"
"household funds" 1.0 0 -13791810 true "" "plot mean [funds] of households"
"education cost" 1.0 0 -2674135 true "" "plot mean [current-education] of humans with [ adult? ] * education-cost"

PLOT
681
228
994
442
Fertility & Education over Time
Time
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"number children" 1.0 0 -5825686 true "" "plot mean [child-count] of humans with [ adult? ]"
"education level" 1.0 0 -955883 true "" "plot mean [current-education] of humans with [ adult? ]"

SLIDER
12
187
195
220
education-cost
education-cost
0
100
30.0
1
1
NIL
HORIZONTAL

SLIDER
12
225
195
258
education-mutation-rate
education-mutation-rate
0
1
0.15
.05
1
NIL
HORIZONTAL

SLIDER
12
110
195
143
adult-mortality-rate
adult-mortality-rate
0
1
0.02
.01
1
NIL
HORIZONTAL

SLIDER
12
71
195
104
child-mortality-rate
child-mortality-rate
0
1
0.08
.01
1
NIL
HORIZONTAL

MONITOR
63
273
143
318
generation
median [generation] of humans
17
1
11

PLOT
1003
228
1295
442
Instantaneous Education vs. Fertility
Education level
Number of Children
0.0
5.0
0.0
5.0
true
false
"" "clear-plot\nask humans with [ adult? ] [ plotxy current-education child-count ]"
PENS
"default" 1.0 2 -8630108 true "" ""

PLOT
1002
10
1295
221
Longevity over Time
Time
Average Lifespan
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [age] of humans"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

person business
false
0
Rectangle -1 true false 120 90 180 180
Polygon -13345367 true false 135 90 150 105 135 180 150 195 165 180 150 105 165 90
Polygon -7500403 true true 120 90 105 90 60 195 90 210 116 154 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 183 153 210 210 240 195 195 90 180 90 150 165
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 76 172 91
Line -16777216 false 172 90 161 94
Line -16777216 false 128 90 139 94
Polygon -13345367 true false 195 225 195 300 270 270 270 195
Rectangle -13791810 true false 180 225 195 300
Polygon -14835848 true false 180 226 195 226 270 196 255 196
Polygon -13345367 true false 209 202 209 216 244 202 243 188
Line -16777216 false 180 90 150 165
Line -16777216 false 120 90 150 165

person construction
false
0
Rectangle -7500403 true true 123 76 176 95
Polygon -1 true false 105 90 60 195 90 210 115 162 184 163 210 210 240 195 195 90
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Circle -7500403 true true 110 5 80
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -955883 true false 180 90 195 90 195 165 195 195 150 195 150 120 180 90
Polygon -955883 true false 120 90 105 90 105 165 105 195 150 195 150 120 120 90
Rectangle -16777216 true false 135 114 150 120
Rectangle -16777216 true false 135 144 150 150
Rectangle -16777216 true false 135 174 150 180
Polygon -955883 true false 105 42 111 16 128 2 149 0 178 6 190 18 192 28 220 29 216 34 201 39 167 35
Polygon -6459832 true false 54 253 54 238 219 73 227 78
Polygon -16777216 true false 15 285 15 255 30 225 45 225 75 255 75 270 45 285

person doctor
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -13345367 true false 135 90 150 105 135 135 150 150 165 135 150 105 165 90
Polygon -7500403 true true 105 90 60 195 90 210 135 105
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -1 true false 105 90 60 195 90 210 114 156 120 195 90 270 210 270 180 195 186 155 210 210 240 195 195 90 165 90 150 150 135 90
Line -16777216 false 150 148 150 270
Line -16777216 false 196 90 151 149
Line -16777216 false 104 90 149 149
Circle -1 true false 180 0 30
Line -16777216 false 180 15 120 15
Line -16777216 false 150 195 165 195
Line -16777216 false 150 240 165 240
Line -16777216 false 150 150 165 150

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

person graduate
false
0
Circle -16777216 false false 39 183 20
Polygon -1 true false 50 203 85 213 118 227 119 207 89 204 52 185
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -8630108 true false 90 19 150 37 210 19 195 4 105 4
Polygon -8630108 true false 120 90 105 90 60 195 90 210 120 165 90 285 105 300 195 300 210 285 180 165 210 210 240 195 195 90
Polygon -1184463 true false 135 90 120 90 150 135 180 90 165 90 150 105
Line -2674135 false 195 90 150 135
Line -2674135 false 105 90 150 135
Polygon -1 true false 135 90 150 105 165 90
Circle -1 true false 104 205 20
Circle -1 true false 41 184 20
Circle -16777216 false false 106 206 18
Line -2674135 false 208 22 208 57

person lumberjack
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -2674135 true false 60 196 90 211 114 155 120 196 180 196 187 158 210 211 240 196 195 91 165 91 150 106 150 135 135 91 105 91
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -6459832 true false 174 90 181 90 180 195 165 195
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -6459832 true false 126 90 119 90 120 195 135 195
Rectangle -6459832 true false 45 180 255 195
Polygon -16777216 true false 255 165 255 195 240 225 255 240 285 240 300 225 285 195 285 165
Line -16777216 false 135 165 165 165
Line -16777216 false 135 135 165 135
Line -16777216 false 90 135 120 135
Line -16777216 false 105 120 120 120
Line -16777216 false 180 120 195 120
Line -16777216 false 180 135 210 135
Line -16777216 false 90 150 105 165
Line -16777216 false 225 165 210 180
Line -16777216 false 75 165 90 180
Line -16777216 false 210 150 195 165
Line -16777216 false 180 105 210 180
Line -16777216 false 120 105 90 180
Line -16777216 false 150 135 150 165
Polygon -2674135 true false 100 30 104 44 189 24 185 10 173 10 166 1 138 -1 111 3 109 28

person police
false
0
Polygon -1 true false 124 91 150 165 178 91
Polygon -13345367 true false 134 91 149 106 134 181 149 196 164 181 149 106 164 91
Polygon -13345367 true false 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -13345367 true false 120 90 105 90 60 195 90 210 116 158 120 195 180 195 184 158 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Polygon -13345367 true false 150 26 110 41 97 29 137 -1 158 6 185 0 201 6 196 23 204 34 180 33
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Rectangle -16777216 true false 109 183 124 227
Rectangle -16777216 true false 176 183 195 205
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Polygon -1184463 true false 172 112 191 112 185 133 179 133
Polygon -1184463 true false 175 6 194 6 189 21 180 21
Line -1184463 false 149 24 197 24
Rectangle -16777216 true false 101 177 122 187
Rectangle -16777216 true false 179 164 183 186

person service
false
0
Polygon -7500403 true true 180 195 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285
Polygon -1 true false 120 90 105 90 60 195 90 210 120 150 120 195 180 195 180 150 210 210 240 195 195 90 180 90 165 105 150 165 135 105 120 90
Polygon -1 true false 123 90 149 141 177 90
Rectangle -7500403 true true 123 76 176 92
Circle -7500403 true true 110 5 80
Line -13345367 false 121 90 194 90
Line -16777216 false 148 143 150 196
Rectangle -16777216 true false 116 186 182 198
Circle -1 true false 152 143 9
Circle -1 true false 152 166 9
Rectangle -16777216 true false 179 164 183 186
Polygon -2674135 true false 180 90 195 90 183 160 180 195 150 195 150 135 180 90
Polygon -2674135 true false 120 90 105 90 114 161 120 195 150 195 150 135 120 90
Polygon -2674135 true false 155 91 128 77 128 101
Rectangle -16777216 true false 118 129 141 140
Polygon -2674135 true false 145 91 172 77 172 101

person soldier
false
0
Rectangle -7500403 true true 127 79 172 94
Polygon -10899396 true false 105 90 60 195 90 210 135 105
Polygon -10899396 true false 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Polygon -10899396 true false 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -6459832 true false 120 90 105 90 180 195 180 165
Line -6459832 false 109 105 139 105
Line -6459832 false 122 125 151 117
Line -6459832 false 137 143 159 134
Line -6459832 false 158 179 181 158
Line -6459832 false 146 160 169 146
Rectangle -6459832 true false 120 193 180 201
Polygon -6459832 true false 122 4 107 16 102 39 105 53 148 34 192 27 189 17 172 2 145 0
Polygon -16777216 true false 183 90 240 15 247 22 193 90
Rectangle -6459832 true false 114 187 128 208
Rectangle -6459832 true false 177 187 191 208

person student
false
0
Polygon -13791810 true false 135 90 150 105 135 165 150 180 165 165 150 105 165 90
Polygon -7500403 true true 195 90 240 195 210 210 165 105
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 100 210 130 225 145 165 85 135 63 189
Polygon -13791810 true false 90 210 120 225 135 165 67 130 53 189
Polygon -1 true false 120 224 131 225 124 210
Line -16777216 false 139 168 126 225
Line -16777216 false 140 167 76 136
Polygon -7500403 true true 105 90 60 195 90 210 135 105
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
