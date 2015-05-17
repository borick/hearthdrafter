function doBreakdown(drops_array, tags_data) {

    var colData = ['Drops'];
    var chart = c3.generate({
        data: {
            columns: [
                colData.concat(drops_array)
            ],
            type: 'bar'
        },
        bindto: "#tabs-3",
        tooltip: {
            contents: function (d, defaultTitleFormat, defaultValueFormat, color) {
                if (tags_data) {
                    //console.log(tags_data[d[0].index]);
                    var out_text = "";
                    out_text = "<div id='drops_tooltip'>" + d[0].value + " drop(s) at " + d[0].index + " mana.<br>";
                    for (var key in tags_data[d[0].index]) {
                        var val = tags_data[d[0].index][key];
                        var name = Object.keys(val)[0];
                        var count = val[name];
                        for(i=0;i<count;i++) {
                            out_text = out_text + '<img width="100" src="' + getCardFileSmall(name) + '"/>';
                        }
                    }
                    out_text = out_text + "</div>";
                    return out_text;
                }
            }   
        }
    });
    chart.axis.labels({
        y: 'Number of Cards',
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