breed [ households household ]
breed [ humans human ]

globals [ global-most-common-gene ]

households-own [
  funds
  real-estate-cost
  education-cost
]

humans-own [
  age
  generation
  adult? ; adult or child
  house ; HOUSEHOLD
  current-education ; current education level
  preferred-education-I ; desired education level, chromosome I
  preferred-education-II ; desired education level, chromosome II
  child-count ; total offspring produced
  dying?
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
  create-humans ( count patches * ( 1 - adult-mortality-rate) ) [
    initialize-human-no-parents
  ]
end

to initialize-human-no-parents
  initialize-human
  set adult? true
  set size 1.0
  set preferred-education-I precision random-float 10 3
  set preferred-education-II precision random-float 10 3
  set current-education ( preferred-education-I + preferred-education-II ) / 2
  move-to one-of patches with [ count humans-here = 0 ]
  setup-new-house
end

to initialize-human-with-parents [ parents ]
  initialize-human
  set adult? false
  set size 0.7
  set generation median [generation] of parents + 1
  ask parents [ set child-count child-count + 1 ]
  set house [house] of one-of parents

  let chrome-list []
  ask parents [ ifelse ( random 2 > 0 ) [ set chrome-list lput preferred-education-I chrome-list ] [ set chrome-list lput preferred-education-II chrome-list ]]
  set preferred-education-I item 0 chrome-list
  set preferred-education-II item 1 chrome-list

  move-to one-of parents
end

to initialize-human
  set age 0
  set hidden? false
  set shape "person"
  set current-education 0
  set child-count 0
  set dying? false
  set generation 0
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go
  ;if stop-at > 0 and ticks >= stop-at [ stop ]
  set global-most-common-gene first most-common-gene
  if ( count humans = count humans with [ preferred-education-I = global-most-common-gene and preferred-education-II = global-most-common-gene ] ) [ stop ]
  ask humans [ if dying? [ make-dead ]]
  ask households [ update-household ]
  ask humans [ set age age + 1 ]
  ask households [ earn-funds ]
  ask households [ invest-in-reproduction  ]
  ask patches with [ bidder != nobody and count humans-here = 0 and phouse = nobody ] [ ask bidder [ add-cell myself ] ]
  ask humans [ calculate-death ]
  tick
end

;:::: HUMANS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to setup-new-house
  hatch-households 1 [
    set funds 0
    ask patch-here [ set phouse myself ]
    set hidden? true
    set color one-of base-colors + random 4 - random 2
    set label-color one-of base-colors + random 4 - random 2
    ask myself [ set house myself ]
  ]
end

to calculate-death
  let lifespan ( 1 / ( adult-mortality-rate + 0.00001) )
  ifelse adult?
  [ ifelse age > lifespan
    [ if ( random-float 1.0 < ( adult-mortality-rate * ( age - ( 1 / adult-mortality-rate ) )))  [ set dying? true ]]
    [ if ( random-float 1.0 < ( adult-mortality-rate )) [ set dying? true ]]]
  [ if random-float 1.0 < child-mortality-rate  [ set dying? true ]]
end

to make-dead
  let h house
  ask patch-here [ set phouse nobody set pcolor black ]
  die
end

;:::: HOUSEHOLDS :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to update-household
  ask patches with [ phouse = myself ] [ set pcolor [color] of myself ]
  ask humans with [ house = myself ] [ set color [label-color] of myself - 3 ]
  if not any? humans with [ adult? and house = myself ] [ kick-out-child household-make-dead ]
end

to earn-funds
  ask humans with [ house = myself and adult? = true ] [
    let money future-benefit-to-present-cost * ( 1 + [current-education] of self )
    ask house [ set funds funds + money ]]
end

to invest-in-reproduction
  ifelse any? humans with [ adult? = false and house = myself ]
    [ invest-in-child ]
    [ ifelse count humans with [ adult? = true and house = myself ] = 2
      [ make-child ]
      [ find-spouse ]]
end

to invest-in-child
  set education-cost 0
  repeat floor ( funds ) [
    let child one-of humans with [ adult? = false and house = myself ]
    ask child [ set current-education current-education + 1 ]
    set funds funds - 1
    set education-cost education-cost + 1
    if ( [current-education] of child >= (( [preferred-education-I] of child + [preferred-education-II] of child ) / 2 ) + 1 ) [ kick-out-child stop ]
  ]
end

to increase-property
  let current-funds funds
  let best-cell nobody
  let lowest-bid 1000000
  ask patches with [ phouse = myself ]
  [ ask neighbors4 with [ phouse = nobody and count humans-here = 0 ]
    [ if ( current-funds > current-bid and current-bid < lowest-bid )
      [ set best-cell self
        set lowest-bid current-bid ]]]
  if best-cell != nobody
  [ ask best-cell [
    set current-bid current-funds
    set bidder myself ]]
end

to add-cell [ cell ]
  ask cell [
    set phouse myself
    set previous-bid [funds] of myself
    ask myself [set real-estate-cost [previous-bid] of myself ]
    set bidder nobody
    set current-bid 0 ]
  set funds 0
end

to kick-out-child
  let child one-of humans with [ adult? = false and house = myself ]
  if child != nobody [
    ask child [
      set adult? true
      set size 1.0
      setup-new-house
    ]]
end

to find-spouse
  if count humans with [ house = myself and adult? = true ] = 1 and count humans with [ house = myself and adult? = false ] = 0 [
    ifelse count patches with [ phouse = myself] >= 2 [
      let other-house one-of other households with [ count humans with [ house = myself and adult? = true ] = 1 and count humans with [ house = myself and adult? = false ] = 0 ]
      if other-house != nobody [
        add-occupant one-of humans with [ house = other-house and adult? = true ] ]]
    [ increase-property ]]
end

to make-child
  let parents humans with [ house = myself and adult? = true ]
  if count parents = 2 and count humans with [ house = myself and adult? = false ] = 0 [
    ifelse count patches with [ phouse = myself ] >= 3 [
      let this-new-human nobody
      hatch-humans 1 [
        set this-new-human self
        initialize-human-with-parents parents ]
      add-occupant this-new-human ]
    [ increase-property ]]
end

to add-occupant [ new-human ]
  ifelse any? patches with [ count humans-here = 0 and phouse = myself ]
    [ ask new-human [
      if house != myself [
        let old-house house
        set house myself
        ask old-house [ household-make-dead ]]
      set house myself
      move-to one-of patches with [ count humans-here = 0 and phouse = [house] of myself ]]]
    [ print "add occupant error" ]
end

to household-make-dead
  ifelse not any? humans with [ house = myself ]
  [ ask patches with [ phouse = myself ] [
      set pcolor black
      set phouse nobody ]
    ask patches with [ bidder = myself ] [ set bidder nobody ]
    die ]
  [ print "household make dead error" ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: DATA :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to print-data
  if count humans > 0 [
    file-print ( word
      ticks " "
      adult-mortality-rate " "
      child-mortality-rate " "
      future-benefit-to-present-cost " "
      get-humans-data ) ]
end

to-report get-humans-data
  let reporter ( word 0 " " 0 " " 0 " " 0 )
  if any? humans [
    set reporter ( word
      precision median [generation] of humans 2 " "
      first most-common-gene " "
      ( median [child-count] of humans with [ adult? ]) " "
      ( median [current-education] of humans with [ adult? ]))]
  report reporter
end

to-report most-common-gene
  let gene-list-I [preferred-education-I] of humans
  let gene-list-II [preferred-education-II] of humans
  let gene-list [ 0 ]
  set gene-list (sentence gene-list gene-list-I gene-list-II)
  report modes gene-list
end
@#$#@#$#@
GRAPHICS-WINDOW
297
20
761
485
-1
-1
45.6
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
9
0
9
1
1
1
ticks
30.0

BUTTON
106
16
169
49
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
32
16
98
49
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

PLOT
774
18
1143
238
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
"cell cost" 1.0 0 -13840069 true "" "if any? humans [ plot median [real-estate-cost] of households ]"
"education cost" 1.0 0 -2674135 true "" "if any? humans [ plot median [education-cost] of households ]"
"household income" 1.0 0 -13791810 true "" "if any? humans [ plot median [funds] of households ]"

PLOT
774
246
1143
467
Tradeoffs over Time
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
"number of children" 1.0 0 -5825686 true "" "if any? humans with [adult?] [ plot median [child-count] of humans with [ adult? ]]"
"education level" 1.0 0 -955883 true "" "if any? humans with [adult?] [ plot median [current-education] of humans with [ adult? ]]"

SLIDER
36
68
264
101
adult-mortality-rate
adult-mortality-rate
0
.1
0.05
.001
1
NIL
HORIZONTAL

SLIDER
36
107
264
140
child-mortality-rate
child-mortality-rate
0
1
0.05
.01
1
NIL
HORIZONTAL

MONITOR
187
11
267
56
generation
median [generation] of humans
1
1
11

PLOT
13
194
286
408
Instantaneous Education vs. Fertility
Education level
Number of Children
0.0
10.0
0.0
50.0
false
false
"" "clear-plot\nask humans with [ adult? ] [ plotxy current-education child-count ]"
PENS
"default" 1.0 2 -7500403 true "" ""

MONITOR
1041
341
1116
386
# children
median [child-count] of humans with [ adult? ]
2
1
11

MONITOR
1041
393
1115
438
education
median [current-education] of humans with [ adult? ]
2
1
11

TEXTBOX
1035
86
1121
104
(median values)
11
3.0
1

TEXTBOX
1031
300
1118
318
(median values)
11
3.0
1

BUTTON
26
424
107
457
go once
go
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
36
144
264
177
future-benefit-to-present-cost
future-benefit-to-present-cost
0
1.0
1.0
.05
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

Fertility Tradeoffs is a NetLogo model that illustrates the emergencent tradeoffs between the quality and quantity of offspring. Often, we associate high fitness with maximizing the number of offspring. However, under certain circumstances, it pays instead to optimize the number of offspring, having fewer offspring than is possible. When the number of offspring is reduced, more energy can be invested in each offspring, which can be beneficial for their own fitness. 

## HOW IT WORKS

When the model is initialized, a population of humans are created and placed in cells. Each square cell of the model is inhabited with at most one human. Some cells are uninhabited and appear black. 

At each timestep, humans (i) earn money based on their education level, (ii) use the money to buy adjacent cells for their spouse and child, and (iii) invest in the education of that child. The INCOME-PER-EDUCATION-LEVEL parameter sets the amount of money humans receive per education level per timestep. The COST-PER-EDUCATION-LEVEL sets the amount of money parents have to pay for their child to earn each education level. Human parents and their child form a “household” of adjacent cells, which are visually represented by color. Many humans may be interested in buying a particular cell and so each cell is auctioned off to the highest bidding human. 

Humans have one evolving (heritable) trait: preferred education level. Parents must use their money to pay for their child’s education until their child reaches their preferred education level. The higher the preferred education level, the longer and more expensive their educational career will be. Once a child reaches their preferred education level, they become adults and leave their parent’s household to establish their own household: buying cells, finding spouses, and making their own children. Human parents only direct their efforts towards one child at a time but, depending on how demanding each child is, they can potentially have several children in a lifetime.

At each timestep, humans have the possibity of dying. The CHILD-MORALITY-RATE parameter dictates, on average, what percentage of children will die at each time step; the ADULT-MORTALITY-RATE does the equivalent for adults.

## HOW TO USE IT

### Parameter Settings

The ADULT-MORTALITY-RATE slider determines the mortality rate of adult humans (adults have left their natal household and have reached their preferred education level). Setting this value too high will result in a population-wide extinction - the inverse of this value is roughly equal to the average lifespan in ticks. Here we are modeling humans and so this parameter is initally set to 0.015, or 67 ticks (years).

The CHILD-MORALITY-RATE slider determines the mortality rate of humans who are classified as children (children still live in their parent's household and haven't completed their preferred education level). This value can be more variable than the ADULT-MORTALITY-RATE, but the specific setting has potentially deep implications for the optimal reproductive strategy!

The INCOME-PER-EDUCATION-LEVEL slider determines the value of each unit of education level. The income a human receives per timestep is calculated as follows:

#### INCOME = CURRENT-EDUCATION x INCOME-PER-EDUCATION-LEVEL

The COST-PER-EDUCATION-LEVEL slider determines the cost per unit of education level. Human parents must pay this amount for each unit of education their child requires.

### Buttons

Press SETUP after all of the settings have been chosen. This will initialize the program to create a population of humans.

Press GO to make the simulation run continuously. Humans will occupy their time earning money, buying cells, finding spouses, and reproducing. To stop the simulation, press the GO button again.

### Output

While it is running, the simulation will show population-level results in four graphs:

The ECONOMY OVER TIME graph shows trends in the population's economy over time. "Real Estate Cost" tracks the median cost per cell. "Education Cost" tracks the median cost of education per human. "Household Income" tracks the median amount of money per household. Positive trends over time indicate a booming economy while negative trends over time indicate a collasping economy.

The TRADEOFFS OVER TIME graph shows trends in the population's reproductive tradeoffs over time. "Number of Children" tracks the median number of children per human. "Education Level" tracks the median preferred education level per human.

The INSTANTANEOUS EDUCATION VS. FERTILITY graph displays the current reproductive and educational status of each adult human. Each human is represented by a dot that is placed on the graph to indicate their current education level and current number of children. This graph refreshes at each timestep.

## THINGS TO NOTICE

The purpose of this model is to demonstrate that humans (and other organisms) experience reproductive tradeoffs: quality of offspring vs. quantity of offspring. The preferred reproductive strategy is context dependent and this model explores the effect of adult and childhood mortality rates. Pay attention to how the settings affect the economy, number of children per human, and preferred education level:

1. When running simulations, notice that there is an inverse relationship between a strategy for more children a strategy for investment in education. Typically two types of strategies emerge: (1) many-children/low-education, and (2) few-children/high-education.

2. Keeping everything else constant, how does the CHILD-MORALITY-RATE affect the preferred reproductive strategy of the population?

3. When you find settings that result in a many-children/low-education reproductive strategy, keep these settings constant and vary COST-PER-EDUCATION-LEVEL. Is it possible to reduce the investment cost such that a few-children/high-education reproductive strategy emerges? Or vice versa?

4. How do the observed results match known human socities?

## HOW TO CITE

Crouse, K. N. (2017).  Fertility Tradeoffs model. Evolutionary Anthropology Lab, Department of Anthropology, University of Minnesota, Minneapolis, MN.

## COPYRIGHT AND LICENSE

Copyright 2017 K N Crouse.

Acknowledgements: Thanks to M L Wilson for comments and suggestions.

This model was created at the University of Minnesota as part of a series of applets to illustrate principles in biological evolution.

The model may be freely used, modified and redistributed provided this copyright is included and the resulting models are not used for profit.

Contact K N Crouse at crou0048@umn.edu if you have questions about its use.
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
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="true">
    <setup>setup
file-open "FertilityTradeoffs20171001_2"</setup>
    <go>go</go>
    <final>print-data</final>
    <steppedValueSet variable="child-mortality-rate" first="0.05" step="0.05" last="1"/>
    <steppedValueSet variable="adult-mortality-rate" first="0.05" step="0.05" last="1"/>
    <steppedValueSet variable="present-cost-to-future-benefit" first="0.05" step="0.05" last="1"/>
  </experiment>
  <experiment name="experiment II" repetitions="100" runMetricsEveryStep="true">
    <setup>setup
file-open "FertilityTradeoffs20171001_3"</setup>
    <go>go</go>
    <final>print-data</final>
    <steppedValueSet variable="child-mortality-rate" first="0.05" step="0.05" last="1"/>
    <enumeratedValueSet variable="adult-mortality-rate">
      <value value="0.015"/>
    </enumeratedValueSet>
    <steppedValueSet variable="present-cost-to-future-benefit" first="0.05" step="0.05" last="1"/>
  </experiment>
  <experiment name="experiment IV" repetitions="100" runMetricsEveryStep="true">
    <setup>setup
file-open "FertilityTradeoffs20171010_1"</setup>
    <go>go</go>
    <final>print-data</final>
    <steppedValueSet variable="child-mortality-rate" first="0.05" step="0.05" last="1"/>
    <enumeratedValueSet variable="adult-mortality-rate">
      <value value="0.05"/>
    </enumeratedValueSet>
    <steppedValueSet variable="present-cost-to-future-benefit" first="0.05" step="0.05" last="2"/>
  </experiment>
</experiments>
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
