/* Global Variables */

var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "/images/cards_small/";
var card_back = '/images/card_backs/small/Card_Back_Legend.png';
var rarity = 'none';
var number_element;
var selected_index = 0;
var selected_card = 0;
var name_to_id = [];

/* Generic Functions */
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
                selected_index = 0;
                highlightElement(selected_index);
        }
    });
}

function initCardClick(i) {
    var ele = $('.card'+(i+1));
    ele.click(function() { showClassCards(i); });
    ele.html('');
    resetTopMessage(i).appendTo(ele);
    makeCardElement(card_back, i).addClass('glow').appendTo(ele);
}
function initCardClicks() {
    for(var i=0;i<3;i++) {
        initCardClick(i);
    }
}

//THE BEGINNING
$(document).ready(function() {    
    
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

//RESPOND TO CARD SELECTION
function showClassCards(id) {
    //selected card name from the list.
    selected_index = 0;
    //selected card option, i.e. card pane.
    selected_card = id;
    console.log('showClassCards:' + id);
    var card_option = getCardElement(id);
    //reset the other card mesages
    for(var c=0;c<3;c++) {
        $('#top_message_'+c).replaceWith(resetTopMessage(c));
        getCardElement(c).removeClass('highlight');
        getCardImage(c).removeClass('glow');
    }
    card_option.addClass('highlight');
    getCardImage(c).removeClass('glow');
    $('#top_message_'+id).text('Please select your card.');
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
                    
            //confirm teh selection of all 3 cards...
            createInputButton($('.card2'), {}, 'Confirm Cards', 'confirm', function ( event ) {
                selected_card = 0;
                selected_index = 0;
                event.preventDefault();
                event.stopPropagation();
                $(this).remove();
                rarity = 'none';
                var pathArray = window.location.pathname.split('/', -1);
                var arena_id = pathArray[3];
                var url = "/draft/card_choice/"+selected[0]+'/'+selected[1]+'/'+selected[2]+'/'+arena_id;
                console.log('getting url: ' + url);                
                //get data
                $.get(url, function( data ) {
                    //GOT DATA!!!!! (scores n shit.)
                    console.log(data);
                    
                    removeConfirm();
                    buildConfirmChoices(arena_id);
                    
                    buildScoreUI(data);
                    buildSynergyUI(data);                    
                });
            });
        } /*else {
            showClassCards(flag);
        }*/
    });
}


function resetTopMessage(id) {
    if (id==0) {
        return setMessageText(id, 'Click or press enter to select.');
    } else {
        return setMessageText(id, 'Click to select.');
    }
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
    $('#card_number').text( (newNumber+1) + '/30');
}

//highlight card names when using arrow keys to select.
function highlightElement(index) {
    for(i = 0;i < $($("li div")).length; i++) {
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

function buildScoreUI (data) {
    for (c=0;c<3;c++) {
        var tmp = $('<span id="odo"><br><b>Card value score is: </b></span>');
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
function getCardImage (id) {
    var card_name = "#card_img_"+(id);
    return $(card_name);
}


function undoCardChoice (id) {
    console.log('undo card:' + id);
    removeConfirm();
    removeHighlight();
    removeConfirmChoices();
    var card_option = getCardElement(id);
    card_option.removeClass('highlight');
    selected[id] = null;
    if(selected[0]==null&&selected[1]==null&&selected[2]==null) {
        rarity='none';
    }
    initCardClick(id);
    removeOdo();
    removeSynergies();
}

function makeCardElement (img,id) {
    return $('<img id="card_img_'+id+'"'+' src="'+img+'">');
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
    makeCardElement(getCardFile(text), id).appendTo(card_option);
    
    card_option.off('click');
    //card_option.text(text + ' selected.');
    return card_option;
    
}

function buildConfirmChoices(arena_id) {
    //make "picked this card" buttons
    for(j = 0; j < selected.length; j++) {
        var tmp_index = j + 1;
        var tmp_card_name = ".card"+tmp_index;
        $(tmp_card_name).removeClass('highlight');
        var ipicked = createInputButton($(tmp_card_name), {}, 'I Picked This Card', j, function ( event ) {
            event.preventDefault();
            event.stopPropagation();
            var selindex = event.data.id;
            var url = "/draft/confirm_card_choice/"+selected[selindex]+'/'+arena_id;
            $.get(url, function( data ) {
                //GOT MORE DATA!!!
                console.log(data);
                card_number += 1;
                if (card_number >= 30) {
                    //TODO: finish arena visualization!
                    $('[class^="card"]').hide();
                    return;
                }
                updateChosenCardsTab(data);
                removeConfirmChoices();
                updateNumber(card_number);
                initCardClicks();
                selected = [];
                hideUndo();
                removeHighlight();
            });
        });
    }
}

function buildSynergyUI(data, id) {
    for(myvar in data['synergy']) {
        synergies = createSynergiesDiv(name_to_id[myvar]);
        var syn_found = 0;
        for (syn in data['synergy'][myvar]) {
            var sync = data['synergy'][myvar][syn]['card_name'];
            var reason = data['synergy'][myvar][syn]['reason'];
            var tmp_div = $('<div class="item"></div>');
            tmp_div.appendTo(synergies.find('[id^="synergies"]'));
            var ce = makeCardElement(getCardFile(sync), name_to_id[myvar]);
            ce.appendTo(tmp_div);
            ce.prop('title', reason);
            syn_found = 1;
        }
        if (!syn_found) {
            $('<p><i>None found.</i>').appendTo(synergies);
        }
        card_pane = $('.card'+(name_to_id[myvar]+1));
        synergies.appendTo(card_pane);
        for(s=0;s<3;s++) {
            $("#synergies"+s).owlCarousel({items:3});
        };
    }   
}

function updateChosenCardsTab (data) {
    console.log('updating chosen cards with:');
    console.log(data);
    var keys = Object.keys(data),
        i, len = keys.length;
    keys.sort();
    $('#tabs-1').html('');
    for (i = 0; i < len; i++) {
        k = keys[i];
        var new_div = $('<span class="capital" id="card_name">'+ k +'</span><span id="card_count">'+ data[k]+'</span><br>'); //has to match select_card.html.ep.
        $('#tabs-1').append(new_div);
    }
}
