breed [ households household ]
breed [ humans human ]

households-own [
 parents
 funds
 children
 cells
]

humans-own [
  age
  generation
  house ; household in which this human lives
  spouse ; other adult in same household

  money ; where income is first stored before distributed to household funds
  adult? ; true = adult or false = child
  current-education ; current education level
  maximum-education ; desired education level
  funds-ratio ; ratio of cell to children funds
  fertility ; desired number of children
  child-count
]

patches-own [
  phouse
  ;density
  resident ; who occupies this space
  bidders
  cost
]

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: SETUP ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to setup
  clear-all
  setup-patches
  setup-humans
  reset-ticks
end

to setup-patches
  ask patches [
    set pcolor black
    set resident nobody
    set phouse nobody
    set bidders []
  ]
end

to setup-humans
  create-humans count patches / 5 [
    initialize-human-no-parents
  ]
end

to initialize-human-with-parents [ parentset ]
  initialize-human
  set color ( [color] of one-of parentset ) - 3
  let me-list []
  ask parentset [ set me-list lput maximum-education me-list ]
  set maximum-education mean me-list
  let fertility-list []
  ask parentset [ set fertility-list lput fertility fertility-list ]
  set fertility mean fertility-list
  set house [house] of one-of parentset
  ask house [ update-household ]
  set generation [generation] of one-of parentset + 1
end

to initialize-human-no-parents
  initialize-human
  move-to one-of patches with [ resident = nobody ]
  setup-new-house
  set adult? true
  set current-education maximum-education
end

to initialize-human
  set hidden? false
  set size 1
  set shape "person"
  set color one-of base-colors - 3
  set money 0
  set spouse nobody
  set adult? false
  set current-education 0
  set maximum-education random 5
  set fertility random 3
  set funds-ratio random-float 1.0
  set child-count 0
  set age 0
  set generation 0
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go
  ask n-of (count humans * mortality-rate) humans [ die ]
  ask humans with [ adult? ] [ earn-money-and-invest ]
  ask humans with [ adult? and spouse = nobody ] [ find-spouse ]
  ask households with [ count parents > 0 ] [ invest-in-children ]
  ask patches with [ length bidders > 0 ] [ join-household ]
  ;maintain-population-density
  ask households [ update-household ]
  ask humans [ set age age + 1 ]
  tick
end

;:::: houseHOLDS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to-report household-fertility
  let fertility-list []
  ask parents [ set fertility-list lput fertility fertility-list ]
  report floor mean fertility-list
end

to-report household-child-count
  let count-list []
  ask parents [ set count-list lput child-count count-list ]
  report floor mean count-list
end

to-report household-has-empty-cells
  report (( count parents + count children ) < count cells )
end

to increase-property
  let me-house self
  let best-cell nobody
  let best-cell-bid-count count patches
  ask cells [ ask neighbors4 with [ resident = nobody and phouse != me-house ]
    [ place-bid me-house ]]
;    [ if length bidders < best-cell-bid-count
;      [ set best-cell self
;        set best-cell-bid-count length bidders ]]]
;  if best-cell != nobody [ ask best-cell [ place-bid myself ]]
end

to invest-in-children
  if count parents = 2 and count children = 0 [ ask cells with [ resident = nobody ] [ make-human [parents] of myself ]]
;  let portion-funds funds  / ( count children + 1 )
;  ;print (word funds " " portion-funds)
;  ask children [ update-education portion-funds ]
;  set funds funds - count children * portion-funds
;  increase-property
  let portion-funds funds
  ifelse count children > 0 [
    ask max-one-of children [current-education] [ update-education portion-funds ]
    set funds 0
  ][
    increase-property
  ]
end

to add-cell [ cell ]
  ask cell [
    set phouse myself
    set pcolor [color] of myself
    set cost [funds] of myself ]
  set funds 0
  update-household
end

to remove-cell [ cell ]
  ask cell [
    set phouse nobody
    set pcolor black ]
  set funds 0
  update-household
end

to update-household
  update-household-parents
  update-household-children
  update-household-cells
  ask parents [ set color [label-color] of myself - 3 ]
  ask children [ set color [label-color] of myself - 2 ]
  ask cells [ set pcolor [color] of myself ]
  if count parents = 0 [ ask children [ make-adult ] household-make-dead ]
  if ( count parents + count children ) = 0 [ household-make-dead ]
end

to update-household-parents
  set parents humans with [ house = myself and adult? = true]
end

to update-household-children
  set children humans with [ house = myself and adult? = false]
end

to update-household-cells
  set cells patches with [ phouse = myself ]
end

to household-make-dead
  ask cells [
    set pcolor black
    set phouse nobody
    set resident nobody ]
  ask patches with [ member? myself bidders ] [ set bidders remove myself bidders ]
  die
end

;:::: HUMANS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to earn-money-and-invest
  set money money + income-rate * current-education
  ask house [ set funds funds + [ money ] of myself ]
  set money 0
end

to find-spouse
  if any? other humans with [ spouse = nobody and adult? and [household-has-empty-cells] of house ] [
    set spouse max-one-of other humans with [ spouse = nobody and adult? and [household-has-empty-cells] of house ] [current-education]
    ask spouse [ set spouse myself ]
    move-into-house [house] of spouse
  ]
end

to move-into-house [ new-house ]
  move-out-of-house
  move-to one-of patches with [ phouse = new-house and resident = nobody ]
  ask patch-here [ set resident myself ]
  set house new-house
  ask house [ update-household ]
end

to move-out-of-house
  ask patch-here [ set resident nobody ]
  let this-house house
  set house nobody
  ask this-house [ update-household ]
end

to setup-new-house
  let hum self
  let h nobody
  hatch-households 1 [
    ask patch-here [ set resident hum ]
    set hidden? true
    set color one-of base-colors + random 2 - random 2
    set label-color one-of base-colors
    set h self ]
  set house h
  ask patch-here [ set phouse h ]
  ask house [ update-household ]
end

to update-education [ fnds ]
  set money money + fnds
  repeat floor ( money / education-cost ) [
    set current-education current-education + 1
    set money money - education-cost
    if current-education >= maximum-education [ make-adult stop ]
  ]
end

to make-adult
  set adult? true
  move-out-of-house
  setup-new-house
end

to make-dead
  let h house
  ask patch-here [ set resident nobody ]
  if spouse != nobody [ ask spouse [ set spouse nobody ]]
  die
  ask h [ update-household ]
end

to mutate-genes
  if random-float 1.0 < mutation-rate [ set maximum-education maximum-education * ( 0.8 + random-float 0.4 ) ]
  if random-float 1.0 < mutation-rate [ set funds-ratio random-float 1.0 ]
  if random-float 1.0 < mutation-rate [ set fertility fertility * ( 0.8 + random-float 0.4 ) ]
end

;:::: CELLS ::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to place-bid [ bidder ]
  set bidders lput bidder bidders
end

to join-household
  if resident = nobody and length bidders > 0 [
    if phouse != nobody [ ask phouse [ remove-cell myself ]]
    if count households with [ member? self [bidders] of myself and funds > 0 ] > 0
      [ ask max-one-of households with [ member? self [bidders] of myself and funds > 0 ] [ funds ] [ add-cell myself ]]
    set bidders []
  ]
end

to make-human [ parentset ]
  sprout-humans 1 [
    initialize-human-with-parents parentset
    move-to myself
    ask patch-here [ set resident myself ]
    mutate-genes
    ask parentset [ set child-count child-count + 1 ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
195
10
658
474
-1
-1
41.4
1
10
1
1
1
0
1
1
1
-5
5
-5
5
1
1
1
ticks
30.0

BUTTON
102
21
165
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
28
21
94
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
13
200
185
233
income-rate
income-rate
1
10
5.07
0.01
1
NIL
HORIZONTAL

PLOT
672
315
891
463
Education vs. Fertility
Education
Fertility
0.0
5.0
0.0
1000.0
true
false
"" ";plotxy current-education child-count\n"
PENS
"point" 1.0 2 -16777216 true "" ""

PLOT
672
166
890
309
Fertility over Time
time
fertility
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [child-count] of humans"

SLIDER
13
239
185
272
education-cost
education-cost
0
100
10.0
1
1
NIL
HORIZONTAL

SLIDER
13
277
185
310
mutation-rate
mutation-rate
0
1
0.05
.01
1
NIL
HORIZONTAL

PLOT
672
15
890
159
Level of Education over Time
time
education
0.0
10.0
0.0
1.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean [current-education] of humans"

MONITOR
57
67
138
112
Generation
mean [generation] of humans
3
1
11

SLIDER
13
124
185
157
population-density
population-density
0
1
0.5
.01
1
NIL
HORIZONTAL

SLIDER
13
162
185
195
mortality-rate
mortality-rate
0
1
0.12
.01
1
NIL
HORIZONTAL

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
