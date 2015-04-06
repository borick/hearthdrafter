/* Global Variables */

var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "/images/cards_medium/";
var card_back = '/images/card_selection_back.png';
var rarity = 'none';
var number_element;
var selected_index = 0;
var selected_card = 0;
var name_to_id = [];
var mode = 'start';
var d = new Date();
var arena_id = 'unknown';
var pathArray = window.location.pathname.split('/', -1);
arena_id = pathArray[3];

/* Generic Functions */
function createElement(e, name, css) {
    div = $("<div/>");
    div.attr({id: name});
    div.css(css);
    e.append(div);
    return div;
}

/**
 * createInputButtom
 * 
 * css - css style to apply
 * name - ID to apply
 * id - ID to pass into the "click" function callback
 * callback - function to call, on click
 */
function createInputButton (e, css, label, name, id, callback) {
    div = $("<div/>");
    div.attr({id: name, class: name});
    div.html();//label);
    div.css(css);
    e.prepend(div);
    //var button = div.button();
    var button = $('<a href="#">'+label+'</a>').prependTo(div);
    button.click({id: id, name: name}, callback);
}

//bindings
$(document).keydown(function(e) {
    switch(e.which) {
        case 13: // enter
            for(z=0;z<3;z++) {
                if(selected[z]==null) {
                    console.log('calling...');
                    showClassCards(z);
                    return;
                }
            }
            break;
    }
});

function rebindKeys() {
    $(".search").off("keydown");
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
                $("li div").get(selected_index).click();
                break;
            default:
                console.log('default: ' + selected_index);
                selected_index = 0;
                highlightElement(selected_index);
        }
    });
}
function resetBG(i) {
    var ele = $('.card'+(i+1));
    ele.css({'background-image':'url('+card_back+')'});
}
function initCardClick(i) {
    var ele = $('.card'+(i+1));
    ele.click(function() { showClassCards(i); });
    ele.html('');
    resetBG(i);
}
function initCardClicks() {
    for(var i=0;i<3;i++) {
        initCardClick(i);
    }
}

//invoked from select_card.html.ep
function loadCardSelection() {
    card_selected = 0;
    initCardClicks();
    rebindKeys();
    //misc layout
    $(".search").hide();
    //card # element positioning
    number_element = createElement($("#top_bar"), 'card_number', {"font-size":"200%"});
    number_element.css({"position":"absolute"});
    number_element.css({'top':'0', 'right':'0'});
    updateNumber(card_number);
    
    cancel_link = createElement($("#top_bar"), 'undo_last_card', {});
    cancel_link.css({"position":"absolute"});
    cancel_link.css({'top':'0', 'right':'0'});
    cancel_link.html('<a href="#" onclick="undoLastCard(); return false;">Undo last card</a>');
    
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
}

function loadChosenCards(data) {
    //GOT DATA!!!!! (scores n stuff.)
    console.log(data);
    
    removeConfirm();
    buildConfirmChoices(arena_id);
    buildScoreUI(data);
}

function confirmCards() {
    mode = 'waiting_for_card';
    selected_card = 0;
    selected_index = 0;
    rarity = 'none';
    var url = "/draft/card_choice/"+selected[0]+'/'+selected[1]+'/'+selected[2]+'/'+arena_id;
    console.log('getting url: ' + url);                
    //get data
    $.get(url, function( data ) {
        loadChosenCards(data);
    });
}

//RESPOND TO CARD SELECTION
function showClassCards(id) {
    selected_index = 0; //reset selection using keyboard to 0.
    selected_card = id;//selected card option, i.e. card pane.
    for(var i=0;i<3;i++) {
        if (id != i && selected[i] == null) {
            resetBG(i);
        }
    }
    var card_option = getCardElement(id);
    card_option.css({background: 'rgba(0,0,0,.75)'});
    var card_names = $('#cards');
    card_names.css({"display": "block", "z-index":9999});
    card_names.addClass('capital');
    card_option.append(card_names); //move the list inside the card...
    rebuildList();
    $(".search").focus();
    highlightElement(selected_index);
    //card selected...
    $(".name").button().click( function( event ) {
        //card name selected
        event.preventDefault();
        event.stopPropagation();
        card_names.css({"display": "none"});
        var element = $(this);
        layoutCardChosen(element.text(), id);
        userList.clear();
        $(".search").hide();
        $('body').append(card_names);//move the list back out lest we destory it
        var flag = 0;
        for (z = 0; z < 3; z++) {
            if (selected[z]==null) {
                flag = z;
                break;
            }   
        }        
        if (flag == 0) {
            //get the card choice data once all 3 are chosen.
            confirmCards();
        }
    });
}


function setMessageText(id,text) {
    return $('<p id="top_message_'+id+'">'+text+'</p>');
}

function createSynergiesDiv(id) {
    var e = $('<div id="synergies'+id+'" class="scroll-img">');
    var outer = $('<div id="outer-synergies'+id+'"><h3>Synergies</h3></div>');
    e.appendTo(outer);
    return outer;
}

//update the number at the end of each turn.
function updateNumber (newNumber) {
    $('#card_number').text( (newNumber) + '/30');
}

//highlight card names when using arrow keys to select.
function highlightElement(index) {
    for(var i = 0;i < $($("li div")).length; i++) {
        if (i == index) {
            $($("li div")[i]).css({"opacity":1.0});
        } else {
            $($("li div")[i]).css({"opacity":0.7});
        }
    }
}

//used by card arrow keys selection
function getCurrentListLength() {
    return $("li div").length;
}

//filters list for proprerty rarirty when card selection changes
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
    userList.on('searchComplete', function() { highlightElement(selected_index) })
    filterList();
    userList.page = 1000;
    userList.sort('name');
    $(".search").val('');
    $(".search").show().focus();
    rebindKeys();
}

function removeUndo () {
    removeElement("#undo");
}

function removeConfirm () {
    removeElement("#confirm");
}

function removeElement(selector) {
    while($(selector).length) {
        for (var i = 0; i < $(selector).length; i++) {
            $(selector).remove();
        }
    }
}

function removeConfirmChoices() {
    removeElement("#ipicked");
}

function removeHighlight () {
    $('div#highlight').hide();
}

function removeSynergies () {
    for(s=0;s<3;s++) {
        $("#outer-synergies"+s).remove();
    }
}

function buildScoreUI (data) {
    for (c=0;c<3;c++) {
        var tmp = $('<span id="odo"></span>');
        tmp.appendTo(getCardElement(c));
        makeOdometer(c).hide().appendTo(tmp);
    }
    var n = 0;
    var m = -100;
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
7
function updateOdometer(id,value) {
    var card_name = '.card_'+(id+1)+'_meter';
    console.log('updating odo with ' + card_name);
    var odo = $(card_name);
    odo.show();
    odo.text(0);
    odo.text(parseInt(value*10000));
}

function removeOdo () {
    $("#odo").remove();
    $("#odo").remove();
    $("#odo").remove();
}

function getCardElement (id) {
    var card_name = ".card"+(id+1);
    return $(card_name);
}

function undoCardChoice (id) {
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

function getCardFile (text) {
    var bg_img = img + card_ids[text] + '.png';
    return bg_img;
}

function layoutCardChosen (text, id) {
     
    var card_option = getCardElement(id);
    card_option.off('click');
    
    console.log('card ' + text + " selected");
    selected[id] = text;
    rarity = card_rarity[text];
    //add image of the card.
    var card_bg_element = $('<div id="card_img_'+id+'"/>');
    card_bg_element.css({'background-image': 'url("'+getCardFile(text)+'")'});
    card_bg_element.appendTo(card_option);
    card_bg_element.addClass('type_'+card_data[text]['type']); //special alignments per type in css.
    //add div for card name
    var card_name_label = $('<div class="card_name_label"/>');
    card_name_label.text(text);
    card_name_label.appendTo(card_option);
    card_name_label.addClass('capital');
    
    //undo button
    var undoButton = createInputButton(card_option, {}, '<img src="/images/cancel.png"/>', "undo", id, function ( event ) {
        $(this).remove();
        undoCardChoice(id);
        event.stopPropagation();
    });
    return card_option;
    
}

function confirmCardByName(name,data) {
    for (i = 0; i < selected.length; i++) {
        if (selected[i] == name) {
            confirmCard(i,data);
            return;
        }
    }
}

function finishConfirm(data) {
    //GOT MORE DATA!!!
    console.log(data);
    card_number += 1;
    if (card_number >= 30) {
        //TODO: finish arena visualization!
        $('[class^="card"]').hide();
        //redirect to results input
        document.location.href = '/draft/results/'+arena_id;
        return;
    }
    updateChosenCardsTab(data);
    removeConfirmChoices();
    updateNumber(card_number);
    initCardClicks();
    selected = [];
    removeUndo();
    removeHighlight();
}

function undoLastCard() {
    if (window.confirm("Are you sure you want to undo the last card choice? There is no redo.")) {
        var url = '/draft/arena_action/undo_last_card_'+arena_id;
        console.log('undo...');
        $.get(url, function( data ) {
            if (card_number == 0) {
                return;
            }
            card_number -= 1;
            removeConfirmChoices();
            updateNumber(card_number);
            initCardClicks();
            selected = [];
            removeUndo();
            removeHighlight(); 
            updateChosenCardsTab(data);
            updateUndoLink();
        });
    }
}

function confirmCard(selindex,auto) {
    if (!auto) {
        var url = "/draft/confirm_card_choice/"+selected[selindex]+'/'+arena_id;
        $.get(url, function( data ) {
            finishConfirm(data);
            updateUndoLink();
        });
    } else {
        finishConfirm(auto);
    }
}
function confirmCardChoice (event) {
    event.preventDefault();
    event.stopPropagation();
    confirmCard(event.data.id);
}

function buildConfirmChoices(arena_id) {
    //make "picked this card" buttons
    for(j = 0; j < selected.length; j++) {
        var tmp_index = j + 1;
        var tmp_card_name = ".card"+tmp_index;
        var ipicked = createInputButton($(tmp_card_name), {}, 'I Picked This Card', 'ipicked', j, function ( event ) {
            confirmCardChoice(event);
        });
    }
}

function updateChosenCardsTab (data) {
    console.log('updating chosen cards with:');
    console.log(data);
    var keys = Object.keys(data),
        i, len = keys.length;
    keys.sort();
    $('#cards_chosen').html('');
    for (i = 0; i < len; i++) {
        k = keys[i];
        var new_div = $('<tr><td id="card_name"><span class="capital">'+ k +'</span></td><td id="card_count">'+ data[k]+'</td></tr>'); //has to match select_card.html.ep.
        $('#cards_chosen').append(new_div);
    }
    updateManaCostChosenCards();//from select_card.html.ep.
}

function updateUndoLink() {
    if (card_number > 0) {
        $("#undo_last_card").show();
    } else {
        $("#undo_last_card").hide();
    }
}