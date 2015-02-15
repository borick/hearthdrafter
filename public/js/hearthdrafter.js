var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "http://wow.zamimg.com/images/hearthstone/cards/enus/original/";
var card_back = 'http://wow.zamimg.com/images/hearthstone/cardbacks/original/Card_Back_Default.png';
var mode = 'none_selected';
var rarity = 'unknown';

$(document).ready(function() {
    console.log( "document loaded" );
    $(".search").hide();
    $('.card1').click(function() {
        showClassCards(0);
    });
    $('.card2').click(function() {
        showClassCards(1);
    });
    $('.card3').click(function() {
        showClassCards(2);
    });
});

function filterList() {
    console.log("inside filter list");
    var newItems = [];
    for (i = 0; i < userList.items.length; i++) {
        var objr =  userList.items[i];
        var obj = objr['_values'];
        var add = 1;
        if (rarity != 'unknown') {
            if (rarity == 'basic' || rarity == 'free' || rarity == 'common') {
                if (obj.rarity != 'basic' && obj.rarity != 'free' && obj.rarity != 'common' ) {
                    add = 0;
                }
            } else if (obj.rarity != rarity) {
                add = 0;
            }
        }
        for(j = 0; j < selected.length; j++) {
            if (selected[j] != null && obj.name == selected[j]) {
                add = 0;
            }
        }
        if (add) {
            newItems.push(objr);
        }
    }
    userList.items = newItems;
}

function rebuildList () {
    if (userList != null) {
        userList.clear();
    }

    var options = {
        valueNames: [ 'name' ],
        item: '<li><div class="name"></div></li>'
    };
    userList = new List('cards', options, cards);
    filterList();
    userList.page = 1000;
    userList.sort('name');
    $(".search").val('');
    $(".search").show().focus();
}

function drawElement(e, name, target, callback){   
    div = $("<div />");
    div.attr({id: name, class: 'element'});
    div.css({top: e.pageY + e.height, left: e.pageX});
    div.html(name);
    $(target).append(div);
    div.button().click(callback);
}

function showClassCards(id) {
    console.log("show class cards clicked"+id);
    
    var index = id + 1;
    var card_name = ".card"+index;
    
    rebuildList();
    
    //pick a card
    $(".name").button().click( function( event ) {
            
        console.log("clicked");
        
        drawElement($(card_name), 'Undo', $(card_name), function ( event ) {
            event.stopPropagation(); $(this).remove();
            selected[id] = null;
            $(card_name).css('background-image', 'url('+card_back+')' );
        } );
        
        event.preventDefault();
        var element = $(this);                     
        var text = element.text();
        selected[id] = text;
        rarity = card_rarity[text];
        console.log('rarity:'+rarity);        
        mode = 'some_selected';
        userList.clear();
        $(".search").hide();
        var bg_img = img + card_ids[text] + '.png';
        console.log(card_name + ":" + bg_img);
        $(card_name).css('background-image', 'url('+bg_img+')' );
        if (selected[0] != null && selected[1] != null && selected[2] != null) {
            mode = 'all_selected';
            
            //confirm teh selection of all 3 cards...
            $('.confirm').text("Confirm").button().click( function( event ) {
                event.preventDefault();
                var pathArray = window.location.pathname.split('/', -1);
                var arena_id = pathArray[3];
                var url = "/draft/card_choice/"+arena_id+'/'+selected[0]+'/'+selected[1]+'/'+selected[2];
                console.log('getting url: ' + url);
                
                //get data
                $.get(url, function( data ) {
                        console.dirxml(data);
                        $('.confirm').remove();
                        selected = [];
                        mode = 'confirm_selected';
                });
            });
        }
      } );
    $(".name").css({ width: '210px' });
    $(".card*").css({ position: 'absolute' });
}