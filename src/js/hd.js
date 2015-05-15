function preload(arrayOfImages) {
    $(arrayOfImages).each(function(){
        $('<img/>')[0].src = this;
    });
}
//console.log(card_data);
function updateManaCostChosenCards() {
    //add the cost to the list of cards
    rows = $('#cards_chosen tr');
    for (i = 0; i < rows.length; i++) {
        jrows = jQuery(rows[i]);
        text = jrows.find('[id=card_name]').text();
        if (typeof(card_data[text]) !== 'undefined') {
            jrows.prepend($('<td id="cost">'+card_data[text]['cost']+'</td>'));
            $("#no_cards").remove();
        } else {
            //TODO: find the hax0r.
            //jrows.prepend($('<td id="cost">?</td>'));
        }
    }
    if (rows.length == 0) {
        $('<span id="no_cards"><i>no cards chosen yet</i></span>').appendTo($('#cards_chosen'));
    }
    sortTable();
}

function updateBreakdown() {
}

function sortTable(){
    var tbl = document.getElementById("cards_chosen").tBodies[0];
    if (tbl == null)
        return;
    var store = [];
    for(var i=0, len=tbl.rows.length; i<len; i++){
        var row = tbl.rows[i];
        var sortnr = parseFloat(row.cells[0].textContent || row.cells[0].innerText);
        if(!isNaN(sortnr)) store.push([sortnr, row]);
    }
    store.sort(function(x,y){
        return x[0] - y[0];
    });
    for(var i=0, len=store.length; i<len; i++){
        tbl.appendChild(store[i][1]);
    }
    store = null;
}

