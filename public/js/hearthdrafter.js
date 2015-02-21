var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "/images/cards_medium/";
var card_back = '/images/card_backs/original/Card_Back_Legend.png';
var rarity = 'none';
var number_element;
var selected_index = 0;

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

function createfunc(i) {
    return function() { showClassCards(i); };
}

function initCardClicks() {
    for(var i=0;i<3;i++) {
        $('.card'+(i+1)).css('background-image', 'url('+card_back+')' );
        $('.card'+(i+1)).click(createfunc(i));
    }
}

function updateNumber (newNumber) {
    $('#card_number').text( (newNumber+1) + '/30');
}
function highlightElement(index) {
    for(i = 0;i < $($("li div")).length; i++) {
        if (i == index) {
            $($("li div")[i]).css({"opacity":0.6});
        } else {
            $($("li div")[i]).css({"opacity":1.0});
        }
    }
}

function getCurrentListLength() {
    return $("li div").length;
}

$(document).ready(function() {    
    console.log( "document loaded" );
    
    initCardClicks();
    //make card element to hold inner image
    for(var i=0;i<3;i++) {
        var ii = createElement($('.card'+(i+1)), 'inside_image', '');
    }
    
    //misc layout
    $(".search").hide();
    //card # element positioning
    number_element = createElement($("#top_bar"), 'card_number', {"font-size":"200%"});
    number_element.css({"position":"absolute"});
    number_element.css({'top':'0', 'right':'0'});
    updateNumber(card_number);
    
    //keep the search focused, where we type card names
    $(document).click(function(event) {
        $(".search").focus();
    });
    //prevent backspace from taking you back.
    $(document).keydown(function(e) {
        if (e.which === 8 && !$(e.target).is("input, textarea")) {
            e.preventDefault();
        }
    });
    $(".search").keydown(function(e) {
        switch(e.which) {
            case 38: // up
                selected_index -= 1;
                if (selected_index < 0)
                    selected_index = 0;
                highlightElement(selected_index);
                break;
            case 40: // down
                selected_index += 1;
                if (selected_index >= getCurrentListLength()-1)
                    selected_index = getCurrentListLength()-1;
                highlightElement(selected_index);
                break;
            case 13: // enter
                $($("li div")[selected_index]).click();
                break;
            default:
                selected_index = 0;
                highlightElement(selected_index);
        }
        console.log("index:"+selected_index);
        //e.preventDefault();
    });
});

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

function getCardElement (id) {
    console.log('getCardElement(' + id +')');
    var card_name = ".card"+(id+1);
    return $(card_name);
}

function undoCardChoice (id) {
    var card_option = getCardElement(id);
    var card_child = card_option.find('#inside_image');
    selected[id] = null;
    if(selected[0]==null&&selected[1]==null&&selected[2]==null) {
        rarity='none';
    }
    //card_option.css('background-image', 'url('+card_back+')' );
    card_option.click(function() {
        showClassCards(id);
    });
    card_option.css({'visibility':'visible'});
    card_child.attr('style', 'display: none');
    card_option.removeClass('cardselected');
}

function layoutCardChosen (card_option, text, id) {
    
    card_option.css({'visibility':'hidden'});
    var child_element = card_option.find('#inside_image');
    child_element.addClass('cardselected');
    console.log('card ' + text + " selected");
    selected[id] = text;
    rarity = card_rarity[text];
    var bg_img = img + card_ids[text] + '.png';
    child_element.attr('style', 'display: block');
    child_element.css('background-image', 'url('+bg_img+')' );
    card_option.off('click');
    return child_element;
    
}

function showClassCards(id) {
    console.log("show class cards clicked"+id);
    selected_index = 0;
    
    var card_option = getCardElement(id);
    var card_names = $('#cards');
    card_names.css({"display": "block", "z-index":9999});
    card_option.append(card_names);
    rebuildList();
    $(".search").focus();
    highlightElement(selected_index);
    
    //pick a card
    $(".name").button().click( function( event ) {
        event.preventDefault();
        event.stopPropagation();
        
        card_names.css({"display": "none"});
        
        var element = $(this);
        var child_element = layoutCardChosen(card_option, element.text(), id);
        //undo button
        createInputButton(child_element, {"margin-left":"70%", "margin-right": "auto", "left": "0", "right": "0"}, 'Undo', id, function ( event ) {
            $(this).remove();
            removeConfirm();
            removeHighlight();
            removeConfirmChoices();
            undoCardChoice(id);
            event.stopPropagation();
        });
        
        userList.clear();
        $(".search").hide();

        if (selected[0] != null && selected[1] != null && selected[2] != null) {
            
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
}