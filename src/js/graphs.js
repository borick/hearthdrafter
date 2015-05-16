function addDropsGraph (dataset_in) {
    
    //Width and height
    var w = 600;
    var h = 250;
    
    var dataset = [ 1,2,3 ];
    if (dataset_in) {
        dataset = dataset_in;
    }

    var xScale = d3.scale.ordinal()
                    .domain(d3.range(dataset.length))
                    .rangeRoundBands([0, w], 0.05);

    var yScale = d3.scale.linear()
                    .domain([0, d3.max(dataset)])
                    .range([0, h]);
    
    //Create SVG element
    var svg = d3.select("#tabs-3")
                .append("svg")
                .attr("width", w)
                .attr("height", h);

    //Create bars
    svg.selectAll("rect")
        .data(dataset)
        .enter()
        .append("rect")
        .attr("x", function(d, i) {
            return xScale(i);
        })
        .attr("y", function(d) {
            return h - yScale(d);
        })
        .attr("width", xScale.rangeBand())
        .attr("height", function(d) {
            return yScale(d);
        })
        .attr("fill", "#009DE5")
//         .attr("fill", function(d) {
//             return "rgb(" + (d*3) + ", " + (d*3) + ", " + (d * 4+100) + ")";
//         })
        .on("mouseover", function(d) {

            //Get this bar's x/y values, then augment for the tooltip
            var xPosition = parseFloat(d3.select(this).attr("x")) + xScale.rangeBand() / 2;
            var yPosition = parseFloat(d3.select(this).attr("y")) / 2 + h / 2;

            //Update the tooltip position and value
            d3.select("#drops_tooltip")
                .style("left", xPosition + "px")
                .style("top", yPosition + "px")                     
                .select("#value")
                .text(d);
        
            //Show the tooltip
            d3.select("#drops_tooltip").classed("hidden", false);

        })
        .on("mouseout", function() {
        
            //Hide the tooltip
            d3.select("#drops_tooltip").classed("hidden", true);
            
        })
        .on("click", function() {
            sortBars();
        });

    //Define sort order flag
    var sortOrder = false;
    
    //Define sort function
    var sortBars = function() {

        //Flip value of sortOrder
        sortOrder = !sortOrder;

        svg.selectAll("rect")
            .sort(function(a, b) {
                if (sortOrder) {
                    return d3.ascending(a, b);
                } else {
                    return d3.descending(a, b);
                }
            })
            .transition()
            .delay(function(d, i) {
                return i * 50;
            })
            .duration(1000)
            .attr("x", function(d, i) {
                return xScale(i);
            });

    };
}