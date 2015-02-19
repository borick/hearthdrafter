var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "http://wow.zamimg.com/images/hearthstone/cards/enus/original/";
var card_back = 'http://wow.zamimg.com/images/hearthstone/cardbacks/original/Card_Back_Default.png';
var mode = 'none_selected';
var rarity = 'none';
var number_element;

function updateNumber (newNumber) {
    $('#card_number').text( (newNumber+1) + '/30');
}

$(document).ready(function() {
    console.log( "document loaded" );
    $(".search").hide();
    initCardClicks();
    number_element = createElement($("#top_bar"), 'card_number',{"font-size":"200%","color":"white"});
    number_element.css({"position":"absolute"});
    number_element.css({'top':'0', 'right':'0'});
    updateNumber(card_number);
});

function initCardClicks() {
    $('.card1').css('background-image', 'url('+card_back+')' );
    $('.card1').click(function() {
        showClassCards(0);
    });
    $('.card2').css('background-image', 'url('+card_back+')' );
    $('.card2').click(function() {
        showClassCards(1);
    });
    $('.card3').css('background-image', 'url('+card_back+')' );
    $('.card3').click(function() {
        showClassCards(2);
    });
}

function filterList() {
    console.log("inside filter list");
    if (rarity == 'none') {
        console.log('doing nothing');
        return;
    }
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

function createElement(e, name, css) {
    div = $("<div/>");
    div.attr({id: name});
    div.css(css);
    e.append(div);
    return div;
}
    
function createInputButton(e, css, name, id, callback){   
    div = $("<div/>");
    div.attr({id: name, class: name});
    div.css({"position":"absolute"});
    div.html(name);
    e.append(div);
    var button = div.button();
    button.click({id: id}, callback);
    div.css(css);
}

function hideUndo () {
    $('.Undo').hide();
}

function removeConfirm () {
    $("[id='Confirm Cards']").remove();
}

function removeConfirmChoices() {
    $("[id='I Picked This Card']").remove();
}

function removeHighlight () {
    $('div#highlight').hide();
}

function showClassCards(id) {
    console.log("show class cards clicked"+id);
    
    var index = id + 1;
    var card_name = ".card"+index;
    
    rebuildList();
    
    //pick a card
    $(".name").button().click( function( event ) {
        event.preventDefault();
        event.stopPropagation();
        var element = $(this);                     
        var text = element.text();//actual card name
        selected[id] = text;
        rarity = card_rarity[text];
        console.log('rarity:'+rarity);        
        mode = 'some_selected';
        
        //undo button
        createInputButton($(card_name), {"margin-left":"70%", "margin-right": "auto", "left": "0", "right": "0"}, 'Undo', id, function ( event ) {
            removeConfirm();
            removeHighlight();
            removeConfirmChoices();
            event.stopPropagation();
            $(this).remove();
            
            selected[id] = null;
            if(selected[0]==null&&selected[1]==null&&selected[2]==null) {
                rarity='none';
            }
            $(card_name).css('background-image', 'url('+card_back+')' );
            $(card_name).click(function() {
                showClassCards(id);
            });
        });
        
        userList.clear();
        $(".search").hide();
        var bg_img = img + card_ids[text] + '.png';
        $(card_name).css('background-image', 'url('+bg_img+')' );
        $(card_name).off('click');
        if (selected[0] != null && selected[1] != null && selected[2] != null) {
            mode = 'all_selected';
            
            //confirm teh selection of all 3 cards...
            createInputButton($('.card2'), {"bottom": "0", "left": "0", "right": "0", "margin-left":"30%","margin-right":"30%" }, 'Confirm Cards', 'confirm', function ( event ) {
                rarity = 'none';
                event.preventDefault();
                event.stopPropagation();
                var pathArray = window.location.pathname.split('/', -1);
                var arena_id = pathArray[3];
                var url = "/draft/card_choice/"+selected[0]+'/'+selected[1]+'/'+selected[2]+'/'+arena_id;
                console.log('getting url: ' + url);
                //get data
                $.get(url, function( data ) {
                    console.dirxml(data);
                    var n = 0;
                    var m = -100;
                    for(j = 0; j < selected.length; j++) {
                        var score = data['scores'][selected[j]];
                        if (score > m) {
                            n = j;
                            m = score;
                        }
                    }
                    //highlight best score card with star
                    var sel_card = '.card' + (n+1);
                    console.log("highlighting " + sel_card);
                    var star = createElement($(sel_card), 'highlight', {'font-size':'500%', 'color':'white', 'position':'absolute'});
                    star.text('*');
                    star.css({"margin-left":"auto", "margin-right": "auto", "left": "0", "right": "0", "bottom": "0"});
                    
                    removeConfirm();

                    for(j = 0; j < selected.length; j++) {
                        var tmp_index = j + 1;
                        var tmp_card_name = ".card"+tmp_index;
                        createInputButton($(tmp_card_name), {"margin-left":"auto", "margin-right": "auto", "left": "0", "right": "0",
                                                             "margin-top":"auto", "margin-bottom": "auto", "top": "0", "bottom": "0", "width":"50%", "height":"55px"}, 'I Picked This Card', j, function ( event ) {
                            event.preventDefault();
                            event.stopPropagation();
                            var selindex = event.data.id;
                            console.log('selindex is: ' + selindex);
                            var url = "/draft/confirm_card_choice/"+selected[selindex]+'/'+arena_id;
                            $.get(url, function( data ) {
                                card_number += 1;
                                if (card_number >= 31) {
                                    //TODO: finish arena visualization!
                                    $('[class^="card"]').hide();
                                    return;
                                }
                                removeConfirmChoices();
                                updateNumber(card_number);
                                initCardClicks();
                                selected = [];
                                hideUndo();
                                removeHighlight();
                            });
                        });
                    }                
                });
            });
        }   
    });
    $(".name").css({ width: '210px' });
    $(".card*").css({ position: 'absolute' });
}