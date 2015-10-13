Timeline axis in CoffeeScript
=============================

Introduction and description
----------------------------

This demo is aimed at exploring possibilities of visualizing time axis.  This especially applies to situations where time axis is meant to be used in interactive plotting, being able to change from very short time intervals to very long time intervals.

Main points of usability of the timeline are:
 * Area that the timeline takes (ideally, as little as possible).
 * Clarity and readability (ideally text/info should be concise and distinctive).
 * How much information is showed (ideally, as much as current zoom level and resolution can afford).
 * Should be easily navigable (should work also for visually impaired).
 * Should be interactive (ideally react according to its representation).

Test cases
----------

### Visual test cases

 1. At least show one time label that corresponds to the provided time interval.

### Unit test cases

To be done:
 * Labels should not intersect with each other
 * There should be at least one label (or no?)
 * Label should be in range if its coordinates are in viewport

Development concerns
--------------------

### Readability

The following things should be thought of before making a final version:
 * DPI should be taken into account.  It should work fine on any DPI display.
 * Every element should be separated from others.
    * Visual elements should not intersect with each other.
    * Visual elements such as labels and ticks should be at some good distance to each other.
 * It is a good idea to alternate colors of intervals.
    * Use two colors.
    * They should differ for visually impaired.
    * And should be suitable for grey-color display.
    * Thus, they should differ in brightness at least.
 * Continuos change (opposed to discrete) between scales (that is zoom levels).
    * Makes it possible to animate without jumps between representation levels, keeping viewer connection to details.
    * Adds more information to viewer.  A question is how to keep this simple enough and not bloated with information and graphics.

### Portability

To make it more flexible to render (to canvas, svg, vega, anything else), we should have an intermediate object as output of axis formatting, which could be rendered after withe a chosen rendeder.

Library functions
-----------------

### The __TimelineMaker__ class

Since formatting and rendering of timeline involves a lot of calculations, it is divided in several functions, and they are combined in the __TimelineMaker__ class.  The __options__ parameter will be a dictionary with values that are needed for formatting the timeline.

    class TimelineMaker
      constructor: (@options) ->

The two functions that are intended to be called are __formatTimeAxis()__, which formats time axis into a dictionary that describes the look of axis, and one of the __renderTo...__ functions that render that data dictionary to a desired context.

#### The __formatTimeAxis()__ function

A function that formats time axis into an intermediate format.  It has two parameters, __interval__ (a dictionary with __start__ and __end__ values, each of Date type) and corresponding to that interval __width__ of a viewport.  It returns a formatted time axis object.  This object is a collection of features with their coordinates in a viewport (the top left point of the viewport is (0,0), the top-right is (0, width)).

      formatTimeAxis: (interval, width) ->
        {@start, end} = interval
        @intervalLength = end - @start
        @width = width

We can put on axis ticks and labels, and also colour areas between them.  They correspond to a set of time points.  Labels could correspond to time points or to time intervals between these points.

Ticks should correspond to _edge points_ of time, a point of time between two days (00-00), two years, months, weeks, or a sharp time point, having integer number of hours, or minutes, or seconds.  In general, while moving from bigger to smaller time interval types, every interval type has to be in integer amount, until  some point.  For example (10 years, 2 months, 3 days) from Epoch and remainder which is less than one day.  That means whe should have a parameter that corresponds to the smallest time interval that has to be integral.  We call this parameter _options.intervalType_.  We also need a number of this intervals between each tick.  This parameter will be __options.intervalMultiplier__.  There is one exception though:  in case of weeks there is no previous integral interval.  So there are two cases:  week and (year, month, day, hour, minute, second, millisecond).

So we need to build a list of time points that correspond to a given time interval.  We will put such code in a special function, __findPointList()__.

        pointList = @findPointList @start, end

Now, when we have found the list of time points, we need to construct a dictionary with graphical element properties.  To transform time value into a coordinate we use the __timeToCoord()__ function.  We start with ticks.  Each tick is a line.  The @options.tickLength parameter is a base length of a tick.

        ticks = for timePoint in pointList
          {
            x: @timeToCoord timePoint
            yTop: -@options.tickLength / 5
            yBottom: @options.tickLength
          }

Now we combine all elements into a one dictionary and return it.

        {ticks: ticks}

#### The __findPointList()__ function

This function returns a list of points that are needed to be calculated for a (__start__, __end__) interval.

      findPointList: (start, end) ->

Since we could need labels between time points, we need time points inside the interval (non-inclusive) and one point on left and right side.  We can build the point list by finding the leftmost _edge point_ which is strictly less than the __start__ of the interval.  We move code that does that to the __findLeftTime()__.

        timePoint = @findLeftTime start

Then, we populate the list in by incrementing points until the we reach right end of the interval, using __findNextPoint()__ function.

        pointList = until timePoint > end
          timePoint = @findNextPoint timePoint

#### The __findLeftTime()__ function

The __findLeftTime()__ function calculates the rightmost point of time for current __options.intervalType__ such that it is not inside the given __interval__ (excluding beginning).  The __options.intervalType__ could be one of the following:
 * 'year'
 * 'month'
 * 'week'
 * 'day'
 * 'hour'
 * 'minute'
 * 'second'
 * 'millisecond'
Another option, __options.intervalMultiplier__, says how many of such intervals are between two time points.  It should be an integer value.  For years and months we truncate them to the desired value, while for days and weeks we will count from a fixed origin day near Epoch (Monday 5 january 1970), so that any day intervals are independent from underlying months and years.  That also means that in case of months the __options.intervalMultiplier__ should be equal to 1, 2, 3, 4 or 6 to be displayed correctly.  To calculate number of days or weeks (reduced to 7 calculation for 7 days) from origin day we use binary subtracting, starting from huge multiplier equal to 1048576 (roughly 2800/11200 years), going down to base multiplier equal to 1.  For interval types smaller or equal than hours we use the __findNextPoint()__ function by incrementing local origin (the interval type and everything smaller is reset to 0).  This is done to avoid problems with daylight-saving and similar things.  In __findNextPoint()__ we make sure that edge points are consistent while using different values of __start__.

      findLeftTime: (start) ->
        leftTime = new Date start.getTime()
        switch @options.intervalType
          when 'year'
            newYear = start.getFullYear() - start.getFullYear() % @options.intervalMultiplier
            leftTime.setFullYear newYear, 0, 1
            leftTime.setHours 0, 0, 0, 0
          when 'month'
            newMonth = start.getMonth() - start.getMonth() % @options.intervalMultiplier
            leftTime.setMonth newMonth, 1
            leftTime.setHours 0, 0, 0, 0
          when 'week', 'day'
            leftTime.setFullYear 1970, 0, 5
            leftTime.setHours 0, 0, 0, 0
            delta = 1048576
            intervalMultiplier = @options.intervalMultiplier
            if @options.intervalType is 'week'
              intervalMultiplier *= 7
            while delta >= 1
              nextTime = new Date leftTime.getFullYear(),
                leftTime.getMonth()
                leftTime.getDate() + delta*intervalMultiplier
                leftTime.getHours()
                leftTime.getMinutes()
                leftTime.getSeconds()
                leftTime.getMilliseconds()
              delta /= 2
              leftTime = nextTime if nextTime <= start
          when 'hour'
            leftTime.setHours 0, 0, 0, 0
            while leftTime < start
              nextTime = @findNextPoint leftTime
              leftTime = nextTime if nextTime <= start
          when 'minute'
            newMinutes = start.getMinutes() - start.getMinutes() % @options.intervalMultiplier
            leftTime.setMinutes newMinutes, 0, 0
          when 'second'
            leftTime.setSeconds start.getSeconds(), 0
            while leftTime < start
              nextTime = @findNextPoint leftTime
              leftTime = nextTime if nextTime <= start
          when 'millisecond'
            newMilliseconds = start.getMilliseconds() - start.getMilliseconds() % @options.intervalMultiplier
            leftTime.setMilliseconds newMilliseconds
        leftTime

There is a code repetition in the switch statement above.  One can think of a good way to improve this part of code.

### The __findNextPoint()__ function

This function calculates next edge time point for a current options assuming __timePoint__ argument is an edge time point.  We take care of daylight-saving time and leap seconds here, assuming that at most one hour/minute/second/millisecond is added or subtracted.  Also we assume that subtraction is not happening at time with 0 value, that is something like 00 -> 23 is not happening.

In current implementation we cope with daylight-saving time by adding hours in UTC to date and then checking how the value changes in local time and fixing by one hour if needed.  The same for leap seconds.

      findNextPoint: (timePoint) ->
        nextTime = new Date timePoint.getTime()
        switch @options.intervalType
          when 'year'
            nextTime.setFullYear (timePoint.getFullYear() + @options.intervalMultiplier)
          when 'month'
            nextTime.setMonth (timePoint.getMonth() + @options.intervalMultiplier)
          when 'week'
            nextTime.setDate (timePoint.getDate() + 7*@options.intervalMultiplier)
          when 'day'
            nextTime.setDate (timePoint.getDate() + @options.intervalMultiplier)
          when 'hour'
            nextTime.setUTCHours (timePoint.getUTCHours() + @options.intervalMultiplier)
            hours = nextTime.getHours()
            if hours % @options.intervalMultiplier isnt 0
              if (hours+1) % @options.intervalMultiplier is 0
                nextTime.setUTCHours (nextTime.getUTCHours() + 1)
              else
                nextTime.setUTCHours (nextTime.getUTCHours() - 1)
          when 'minute'
            nextTime.setMinutes (timePoint.getMinutes() + @options.intervalMultiplier)
          when 'second'
            nextTime.setUTCSeconds (timePoint.getUTCSeconds() + @options.intervalMultiplier)
            seconds = nextTime.getSeconds()
            if seconds % @options.intervalMultiplier isnt 0
              if (seconds+1) % @options.intervalMultiplier is 0
                nextTime.setUTCSeconds (nextTime.getUTCSeconds() + 1)
              else
                nextTime.setUTCSeconds (nextTime.getUTCSeconds() - 1)
          when 'millisecond'
            nextTime.setUTCMilliseconds (timePoint.getUTCMilliseconds() + @options.intervalMultiplier)
        nextTime

#### The __timeToCoord()__ function

To get coordinate of time point we use `@intervalLength` that we stored in `formatTimeAxis()`, which is equal to the number of milliseconds between `end` and `start` of the interval.  We use it to calculate pixe/time ratio, equal to `@width / @intervalLength`.

      timeToCoord: (time) ->
        timeFromStart = time - @start
        coordinate = timeFromStart * @width / @intervalLength

#### The __renderToCanvas()__ function

This function renders formatted time axis to html canvas.
 * `axisData` is formatted data (that we get by calling any of the `format...()` functions)
 * `canvas` is a html canvas object on which axis is drawn
 * `left` and `top` are x- and y-coordinates of the canvas that correspond to the (0, 0) point of the axis viewport

      renderToCanvas: (axisData, canvas, left, top) ->

In the beginning we do just regular initialization of context and its properties.  We also wrap our drawing code into `save()` and `restore()` to not alter context properties globally.

        context = canvas.getContext '2d'
        context.save()
        context.strokeStyle = '#000000'
        context.lineWidth = 2
        context.clearRect 0, 0, canvas.width, canvas.height

To all drawing functions we pass coordinates altered by `roundForCanvas()` function, which rounds values in such a way that the resulting graphics is more sharp (especially horizontal and vertical lines and text).

        for tick in axisData.ticks
          x = left + tick.x
          yTop = top + tick.yTop
          yBottom = top + tick.yBottom
          context.moveTo @roundForCanvas(x), @roundForCanvas(yTop)
          context.lineTo @roundForCanvas(x), @roundForCanvas(yBottom)
        context.stroke()

        context.restore()

#### The `roundForCanvas()` function

This function may be used to avoud aliasing, especially on low-resolution displays.  It rounds coordinate to middle-pixel values, which are .5 in case of html canvas.

      roundForCanvas: (coord) ->
        0.5 + Math.round(coord-0.5)

Library tests
-------------

Examples
--------

This simple code displays time axis when html page is loaded, in `timeline` canvas element.

    makeDemo = ->
      canvas = document.getElementById 'timeline'
      timelineMaker = new TimelineMaker {tickLength: 25, intervalType: 'day', intervalMultiplier: 1}
      start = new Date('2015-06-15T00:00:00')
      end = new Date('2015-07-13T15:23:49')
      axisData = timelineMaker.formatTimeAxis {start, end}, canvas.width
      timelineMaker.renderToCanvas axisData, canvas, 0, 15

    window.onload = makeDemo