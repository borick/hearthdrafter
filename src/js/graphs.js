function doBreakdown(drops_array) {

    var colData = ['Drops'];
    var chart = c3.generate({
        data: {
            columns: [
                colData.concat(drops_array)
            ],
            type: 'bar',
            color: "white"
        },
        bindto: "#tabs-3"
    });
    chart.axis.labels({
    y: 'Number of Drops',
    x: 'Turn Played'
    });
    
    //tab it up
    $(function() {
        var tabs = $( "#tabs" ).tabs();
        tabs.find( ".ui-tabs-nav" ).sortable({
            axis: "x",
            stop: function() {
            tabs.tabs( "refresh" );
            }
        });
    });
    
}