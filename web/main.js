var showValue = function(newValue) {
  document.getElementById("range-label").innerHTML = newValue;
  applyStateClasses(newValue);
};
// debounce here improves slider responsiveness on mobile
showValue = _.debounce(showValue, 10, true);

var width = 960,
    height = 500;

var rateById = {
  '1990': d3.map(),
  '1991': d3.map(),
  '1992': d3.map(),
  '1993': d3.map(),
  '1994': d3.map(),
  '1995': d3.map(),
  '1996': d3.map(),
  '1997': d3.map(),
  '1998': d3.map(),
  '1999': d3.map(),
  '2000': d3.map(),
  '2001': d3.map(),
  '2002': d3.map(),
  '2003': d3.map(),
  '2004': d3.map(),
  '2005': d3.map(),
  '2006': d3.map(),
  '2007': d3.map(),
  '2008': d3.map(),
  '2009': d3.map(),
  '2010': d3.map(),
  '2011': d3.map(),
  '2012': d3.map()
};

var quantize = d3.scale.quantize()
    .domain([0, 50000])
    .range(d3.range(9).map(function(i) { return "q" + i + "-9"; }));

var path = d3.geo.path();


queue()
    .defer(d3.json, "us.json")
    .defer(d3.tsv, "per-capita-personal-income-by-state-1990-2012.tsv", function(d) {
      rateById[d.year].set(+d.id, +d.rate);
    })
    .await(ready);


function drawMap(year){
  clearMap();
//   document.getElementById("map").innerHTML = "";
  var svg = d3.select("#map").append("svg")
      .attr("width", width)
      .attr("height", height);
  svg.append("g")
      .attr("class", "states")
    .selectAll("path")
      .data(topojson.feature(us, us.objects.states).features)
    .enter().append("path")
      .attr("class", function(d) { return quantize(rateById[year].get(d.id)); })
      .attr("id", function(d) {
        return "state-" + d.id;
      })
      .attr("d", path);
}

function applyStateClasses(year) {
    var states = d3.selectAll("#map g path");
    states.each(function(stateFeature) {
        var state = d3.select(this),
            cls = quantize(rateById[year].get(stateFeature.id));
        state.attr("class", cls);
    });
}

function clearMap(){
  document.getElementById("map").innerHTML = "";
}

var us = null;
function ready(error, data) {
  us = data;
  drawMap('1990');
  showValue('1990');
}
