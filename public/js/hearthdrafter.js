var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "/images/cards_small/";
var card_back = '/images/card_backs/small/Card_Back_Legend.png';
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
function createInputButton (e, css, name, id, callback) {
    div = $("<br><div/>");
    div.attr({id: name, class: name});
    div.html(name);
    e.append(div);
    var button = div.button();
    button.click({id: id}, callback);
    div.css(css);
    return button;
}

function createfunc(i) {
    return function() { showClassCards(i); };
}

function createSynergiesDiv(id) {
    var e = $('<div id="synergies'+id+'" class="scroll-img">');
    var outer = $('<div id="outer-synergies'+id+'"><h3>Synergies</h3></div>');
    e.appendTo(outer);
    return outer;
}

function rebindKeys() {
    $(".search").off("keydown");
    $(".search").keydown(function(e) {
        //console.log('test');
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
    });
}

function makeOdometer(id) {
    id = id + 1;
    var new_ele = $('<div class="odometer card_'+id+'_meter">0</div>');
    od = new Odometer({
      el: new_ele.get(0),
      value: 0,
      format: '',
      theme: 'minimal',
    });
    return new_ele;
    
}
function updateOdometer(id,value) {
    var card_name = '.card_'+(id+1)+'_meter';
    console.log('updating odo with ' + card_name);
    var odo = $(card_name);
    odo.show();
    odo.text(0);
    odo.text(parseInt(value*10000));
}
function initCardClick(i) {
    var ele = $('.card'+(i+1));
    ele.click(createfunc(i));
    ele.html('');
    $('<p>Click here to select a card.</p>').appendTo(ele);
    makeCardElement(card_back).appendTo(ele);
}
function initCardClicks() {
    for(var i=0;i<3;i++) {
        initCardClick(i);
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

//THE BEGINNING
$(document).ready(function() {    
    
    initCardClicks();
    rebindKeys();
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
        rebindKeys();
    });
    //prevent backspace from taking you back.
    $(document).keydown(function(e) {
        if (e.which === 8 && !$(e.target).is("input, textarea")) {
            e.preventDefault();
        }
    });
    $("#top_bar").css({'visibility':'visible'}).hide().fadeIn('fast', function() {} );
    
});

function filterList() {
    if (rarity == 'none') {
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
    rebindKeys();
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

function removeSynergies () {
    for(s=0;s<3;s++) {
        $("#outer-synergies"+s).remove();
    }
}

function removeOdo () {
    $("#odo").remove();
    $("#odo").remove();
    $("#odo").remove();
}

function getCardElement (id) {
    var card_name = ".card"+(id+1);
    console.log('getCard:' + card_name);
    return $(card_name);
}

function undoCardChoice (id) {
    console.log('undo card:' + id);
    removeConfirm();
    removeHighlight();
    removeConfirmChoices();
    var card_option = getCardElement(id);
    selected[id] = null;
    if(selected[0]==null&&selected[1]==null&&selected[2]==null) {
        rarity='none';
    }
    initCardClick(id);
    removeOdo();
    removeSynergies();
}

function makeCardElement (img) {
    return $('<img src="'+img+'">');
}
function getCardFile (text) {
    var bg_img = img + card_ids[text] + '.png';
    return bg_img;
}

function layoutCardChosen (card_option, text, id) {
    console.log('card ' + text + " selected");
    selected[id] = text;
    rarity = card_rarity[text];
    
    card_option.html('');
    $('<p><span class="capital">'+text+'</span> selected.</p>').appendTo(card_option);
    makeCardElement(getCardFile(text)).appendTo(card_option);
    
    card_option.off('click');
    //card_option.text(text + ' selected.');
    return card_option;
    
}

//CARD CLICKED.
function showClassCards(id) {
    selected_index = 0;
    console.log('showClassCards:' + id);
    var card_option = getCardElement(id);
    var card_names = $('#cards');
    card_names.css({"display": "block", "z-index":9999});
    card_names.addClass('capital');
    card_option.append(card_names); //move the list inside the card...
    rebuildList();
    $(".search").focus();
    highlightElement(selected_index);
    //pick a card
    $(".name").button().click( function( event ) {
        //card name selected
        event.preventDefault();
        event.stopPropagation();
        
        card_names.css({"display": "none"});
        var element = $(this);
        
        layoutCardChosen(card_option, element.text(), id);
        //undo button
        var undoButton = createInputButton(card_option, {}, 'Undo', id, function ( event ) {
            $(this).remove();
            undoCardChoice(id);
            event.stopPropagation();
        });
        undoButton.text('Correct Card Choice');
        userList.clear();
        $(".search").hide();
        $('body').append(card_names);//move the list back out lest we destory it
        if (selected[0] != null && selected[1] != null && selected[2] != null) {
            
            //confirm teh selection of all 3 cards...
            createInputButton($('.card2'), {}, 'Confirm Cards', 'confirm', function ( event ) {
                
                event.preventDefault();
                event.stopPropagation();
                $(this).remove();
                rarity = 'none';
                var pathArray = window.location.pathname.split('/', -1);
                var arena_id = pathArray[3];
                var url = "/draft/card_choice/"+selected[0]+'/'+selected[1]+'/'+selected[2]+'/'+arena_id;
                console.log('getting url: ' + url);
                for (c=0;c<3;c++) {
                    var tmp = $('<span id="odo"><br><b>Card value score is: </b></span>');
                    tmp.appendTo(getCardElement(c));
                    makeOdometer(c).hide().appendTo(tmp);
                }
                //get data
                $.get(url, function( data ) {
                    //GOT DATA!!!!! (scores n shit.)
                    console.log(data);
                    
                    //make "picked this card" buttons
                    for(j = 0; j < selected.length; j++) {
                        var tmp_index = j + 1;
                        var tmp_card_name = ".card"+tmp_index;
                        var ipicked = createInputButton($(tmp_card_name), {}, 'I Picked This Card', j, function ( event ) {
                            event.preventDefault();
                            event.stopPropagation();
                            var selindex = event.data.id;
                            var url = "/draft/confirm_card_choice/"+selected[selindex]+'/'+arena_id;
                            $.get(url, function( data ) {
                                //GOT MORE DATA!!!
                                console.log(data);
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

                    var n = 0;
                    var m = -100;
                    var name_to_id = [];
                    var synergies;
                    var card_pane;
                    for(j = 0; j < selected.length; j++) {
                        console.log(selected[j]);
                        name_to_id[selected[j]] = j;
                        var score = data['scores'][selected[j]];
                        if (score > m) {
                            n = j;
                            m = score;
                        }
                        updateOdometer(j, score);
                    }
                    for(myvar in data['synergy']) {
                        synergies = createSynergiesDiv(name_to_id[myvar]);
                        var syn_found = 0;
                        for (syn in data['synergy'][myvar]) {
                            var sync = data['synergy'][myvar][syn]['card_name'];
                            var reason = data['synergy'][myvar][syn]['reason'];
                            console.log('my card: ' + myvar);
                            console.log('my syn: ' + sync);
                            console.log('my reason: ' + reason);
                            var tmp_div = $('<div class="item"></div>');
                            tmp_div.appendTo(synergies.find('[id^="synergies"]'));
                            makeCardElement(getCardFile(sync)).appendTo(tmp_div);
                            syn_found = 1;
                        }
                        if (!syn_found) {
                            $('<p><i>empty</i>').appendTo(synergies);
                        }
                        card_pane = $('.card'+(name_to_id[myvar]+1));
                        synergies.appendTo(card_pane);
                        for(s=0;s<3;s++) {
                            $("#synergies"+s).owlCarousel({items:3});
                        };
                    }
                    
                    var sel_card = '.card' + (n+1);
                    //TODO:add more messages
                    
                    removeConfirm();
                });
            });
        }   
    });
}