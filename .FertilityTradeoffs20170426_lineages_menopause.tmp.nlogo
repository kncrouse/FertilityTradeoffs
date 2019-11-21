breed [ households household ]
breed [ humans human ]

globals [
  current


]

households-own [
  funds
]

humans-own [
  age
  sex
  generation
  menopause
  adult? ; adult or child
  house ; HOUSEHOLD
  current-education ; current education level
  preferred-education ; desired education level
  child-count ; total offspring produced
  dying?
  ancestral-education
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
  set current 0
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
  set current current + 0.1
  initialize-human
  set adult? true
  set size 1.0
  set preferred-education precision current 1
  set current-education preferred-education
  set ancestral-education preferred-education
  set label ancestral-education
  set menopause 90
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
  set preferred-education mean [preferred-education] of parents - random 2 + random 2
  set ancestral-education [ancestral-education] of one-of parents
  set menopause mean [menopause] of parents - random 2 + random 2
  set label ancestral-education
  move-to one-of parents
end

to initialize-human
  set age 0
  set hidden? false
  set sex one-of [ "male" "female" ]
  set shape ifelse-value (sex = "female") [ "female person" ] [ "male person" ]
  set current-education 0
  set child-count 0
  set dying? false
  set generation 0
  set label-color white
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: GO :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to go
  if stop-at > 0 and ( median [generation] of humans ) >= stop-at [ stop ]
  ask humans [ if dying? [ make-dead ]]
  ask households [ update-household ]
  ask humans [ set age age + 1 ]
  ask households [ earn-funds ]
  ask households [ invest-in-reproduction  ]
  ask patches with [ bidder != nobody and count humans-here = 0 and phouse = nobody ] [ ask bidder [ add-cell myself ] ]
  ask humans [ calculate-death ]
  if allow-lateral-transmission? [ ask humans [ if any? other humans in-radius 1 [ ask one-of other humans in-radius 1 [ set preferred-education [preferred-education] of myself ]]]]
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
  if not any? humans with [ house = myself ] [ household-make-dead ]
end

to earn-funds
  ask humans with [ house = myself ] [
    let money income-per-education-level * ( [current-education] of self )
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
  repeat floor ( funds / cost-per-education-level ) [
    let child one-of humans with [ adult? = false and house = myself ]
    ask child [ set current-education current-education + 1 ]
    set funds funds - cost-per-education-level
    if ( [current-education] of child >= [preferred-education] of child ) [ kick-out-child stop ]
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
  ifelse count humans with [ house = myself and adult? = true ] = 1 and count humans with [ house = myself and adult? = false ] = 0 [
    let my-humans-sex [sex] of one-of humans with [ house = myself and adult? = true ]
    ifelse count patches with [ phouse = myself] >= 2 [
      let other-house one-of other households with [ count humans with [ house = myself and adult? = true ] = 1 and count humans with [ house = myself and adult? = false ] = 0 ]
      if other-house != nobody [ add-occupant one-of humans with [ house = other-house and adult? = true and sex != my-humans-sex ] ]]
    [ increase-property ]]
  [ print "find spouse error" ]
end

to make-child
  let parents humans with [ house = myself and adult? = true ]
  let mother one-of parents with [ sex = "female" ]
  if count parents = 2 and count humans with [ house = myself and adult? = false ] = 0 and [age] of mother < [menopause] of mother [
    ifelse count patches with [ phouse = myself ] >= 3 [
      let this-new-human nobody
      hatch-humans 1 [
        set this-new-human self
        initialize-human-with-parents parents ]
      add-occupant this-new-human ]
    [ increase-property ]]
end

to add-occupant [ new-human ]
  if new-human != nobody [
    ifelse any? patches with [ count humans-here = 0 and phouse = myself ]
    [ ask new-human [
      if house != myself [
        let old-house house
        set house myself
        ask old-house [ household-make-dead ]]
      set house myself
      move-to one-of patches with [ count humans-here = 0 and phouse = [house] of myself ]]]
    [ print "add occupant error" ]]
end

to household-make-dead
  ifelse not any? humans with [ house = myself ]
  [ ask patches with [ phouse = myself ] [
      set pcolor black
      set phouse nobody ]
    ask patches with [ bidder = myself ] [ set bidder nobody ]
    die ]
  [ print ( word self " household make dead error") ]
end

;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::: DATA :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
;:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::

to print-data
  print ( word
  allow-lateral-transmission? " "
  stop-at " "
  adult-mortality-rate " "
  child-mortality-rate " "
  income-per-education-level " "
  cost-per-education-level " "
  ( median [child-count] of humans with [ adult? ]) " "
  ( median [current-education] of humans with [ adult? ]) " "
  [ancestral-education] of one-of humans )
end
@#$#@#$#@
GRAPHICS-WINDOW
215
10
678
474
-1
-1
45.5
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
111
20
174
53
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
37
20
103
53
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
9
181
205
214
income-per-education-level
income-per-education-level
1
10
5.0
1
1
NIL
HORIZONTAL

PLOT
691
10
968
239
Economy over Time
Time
Money
0.0
5.0
0.0
1.0
true
false
"" ""
PENS
"real estate" 1.0 0 -13840069 true "" "plot median [previous-bid] of patches"

PLOT
690
246
968
473
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
"fertility" 1.0 0 -5825686 true "" "plot median [child-count] of humans with [ adult? ]"
"education" 1.0 0 -955883 true "" "plot median [current-education] of humans with [ adult? ]"

SLIDER
9
220
206
253
cost-per-education-level
cost-per-education-level
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
10
104
204
137
adult-mortality-rate
adult-mortality-rate
0
.1
0.015
.001
1
NIL
HORIZONTAL

SLIDER
10
143
205
176
child-mortality-rate
child-mortality-rate
0
1
0.3
.01
1
NIL
HORIZONTAL

MONITOR
65
308
145
353
generation
median [generation] of humans
1
1
11

PLOT
975
10
1215
165
Individual Strategies
Education
Fertility
0.0
10.0
0.0
50.0
true
false
"" "clear-plot\nask humans with [ adult? ] [ plotxy current-education child-count ]"
PENS
"default" 1.0 2 -7500403 true "" ""

MONITOR
899
360
962
405
fertility
median [child-count] of humans with [ adult? ]
2
1
11

MONITOR
898
412
962
457
education
median [current-education] of humans with [ adult? ]
2
1
11

TEXTBOX
904
300
953
318
(median)
11
3.0
1

SLIDER
10
65
203
98
stop-at
stop-at
0
1000
1000.0
10
1
generations
HORIZONTAL

PLOT
977
169
1215
324
Lineage Persistence
Lineage
Generations
0.0
10.0
0.0
10.0
true
false
"" "let i 0.1 \nwhile [i < 10] [\nif any? humans with [ ancestral-education > i and ancestral-education <= i + 0.1 ] [\nplotxy i [generation] of max-one-of humans with [ ancestral-education > i and ancestral-education <= i + 0.1  ] [generation] ]\nset i i + 0.1\n]"
PENS
"default" 1.0 2 -16777216 true "" ""

PLOT
978
328
1216
475
Lineage Histogram
Lineage
Frequency
0.0
10.0
0.0
10.0
true
false
"set-histogram-num-bars 100" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [ancestral-education] of humans"

SWITCH
9
259
206
292
allow-lateral-transmission?
allow-lateral-transmission?
1
1
-1000

PLOT
1223
10
1423
160
plot 1
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot median [menopause] of humans"
"pen-1" 1.0 0 -7500403 true "" "if any? humans with [ dying? = true and adult? = true ] [plot median [age] of humans with [ dying? = true and adult? = true ]]"

BUTTON
129
515
210
548
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

female person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
Polygon -7500403 true true 120 195 180 195 225 255 75 255 120 195

male person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup
file-open "FertilityTradeoffs20170424D_2"</setup>
    <go>go</go>
    <final>print-data</final>
    <steppedValueSet variable="child-mortality-rate" first="0.01" step="0.01" last="1"/>
    <enumeratedValueSet variable="adult-mortality-rate">
      <value value="0.015"/>
    </enumeratedValueSet>
    <steppedValueSet variable="cost-per-education-level" first="5" step="5" last="100"/>
    <enumeratedValueSet variable="income-per-education-level">
      <value value="5"/>
    </enumeratedValueSet>
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
