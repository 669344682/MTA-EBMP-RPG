local database = dbConnect( "sqlite", "ebmp-rpg.db" )
function sqlite(text)
	local result1 = dbQuery( database, text )
	local result = dbPoll( result1, -1 )
	dbFree(result1)

	if string.find(text, "UPDATE") or string.find(text, "INSERT") or string.find(text, "DELETE") then
		local time = getRealTime()
		local hour = time["hour"]
		local minute = time["minute"]
		local second = time["second"]

		if time["hour"] < 10 then
			hour = "0"..hour
		end

		if time["minute"] < 10 then
			minute = "0"..minute
		end

		if time["second"] < 10 then
			second = "0"..second
		end

		local client_time = "[Date: "..time["monthday"].."."..time["month"]+'1'.."."..time["year"]+'1900'.." Time: "..hour..":"..minute..":"..second.."] "
		local hFile = fileOpen(":save_sql/save_sqlite.sql")
		fileSetPos( hFile, fileGetSize( hFile ) )
		fileWrite(hFile, client_time..text.."\n" )
		fileClose(hFile)
	end

	return result
end
addEvent("event_sqlite", true)
addEventHandler("event_sqlite", root, sqlite)

local earth = {}--слоты земли
local max_earth = 0--мак-ое кол-во выброшенных предметов на землю
local count_player = 0--кол-во подключенных игроков
local max_inv_additional = 1--дополнительные слоты
local tomorrow_weather = 0--погода
local spawnX, spawnY, spawnZ = 1672.5390625,1447.8193359375,10.788088798523--стартовая позиция
local business_pos = {}--позиции бизнесов
local house_pos = {}--позиции домов
local ferm_etap = 1--этап фермы, всего 3
local grass_pos_count = 0--кол-во убранных растений на ферме
local ferm_etap_count = 255--кол-во этапов за раз
local loto = {0, {}, false}--лотерея
local no_ped_damage = {--таблица нпс по которым не будет проходить дамаг
	createPed ( 312, 2435.337890625,-2704.7568359375,3, 180.0, true ),
	createPed ( 312, -1632.9775390625,-2239.0263671875,31.4765625, 90.0, true ),
}

----цвета----
local color_mes = {
	color_tips = {168,228,160},--бабушкины яблоки
	yellow = {255,255,0},--желтый
	red = {255,0,0},--красный
	red_try = {200,0,0},--красный
	blue = {0,150,255},--синий
	white = {255,255,255},--белый
	green = {0,255,0},--зеленый
	green_try = {0,200,0},--зеленый
	turquoise = {0,255,255},--бирюзовый
	orange = {255,100,0},--оранжевый
	orange_do = {255,150,0},--оранжевый do
	pink = {255,100,255},--розовый
	lyme = {130,255,0},--лайм админский цвет
	svetlo_zolotoy = {255,255,130},--светло-золотой
	crimson = {220,20,60},--малиновый
	purple = {175,0,255},--фиолетовый
	gray = {150,150,150},--серый
	green_rc = {115,180,97},--темно зеленый
}

local color_table = {
	--color gtasa
	{0,0,0},{245,245,245},{42,119,161},{132,4,16},{38,55,57},{134,68,110},{215,142,16},{76,117,183},{189,190,198},{94,112,114},
	{70,89,122},{101,106,121},{93,126,141},{88,89,90},{214,218,214},{156,161,163},{51,95,63},{115,14,26},{123,10,42},{159,157,148},
	{59,78,120},{115,46,62},{105,30,59},{150,145,140},{81,84,89},{63,62,69},{165,169,167},{99,92,90},{61,74,104},{151,149,146},
	{66,31,33},{95,39,43},{132,148,171},{118,123,124},{100,100,100},{90,87,82},{37,37,39},{45,58,53},{147,163,150},{109,122,136},
	{34,25,24},{111,103,95},{124,28,42},{95,10,21},{25,56,38},{93,27,32},{157,152,114},{122,117,96},{152,149,134},{173,176,176},
	{132,137,136},{48,79,69},{77,98,104},{22,34,72},{39,47,75},{125,98,86},{158,164,171},{156,141,113},{109,24,34},{78,104,129},
	{156,156,152},{145,115,71},{102,28,38},{148,157,159},{164,167,165},{142,140,70},{52,26,30},{106,122,140},{170,173,142},{171,152,143},
	{133,31,46},{111,130,151},{88,88,83},{154,167,144},{96,26,35},{32,32,44},{164,160,150},{170,157,132},{120,34,43},{14,49,109},
	{114,42,63},{123,113,94},{116,29,40},{30,46,50},{77,50,47},{124,27,68},{46,91,32},{57,90,131},{109,40,55},{167,162,143},
	{175,177,177},{54,65,85},{109,108,110},{15,106,137},{32,75,107},{43,62,87},{155,159,157},{108,132,149},{77,93,96},{174,155,127},
	{64,108,143},{31,37,59},{171,146,118},{19,69,115},{150,129,108},{100,104,106},{16,80,130},{161,153,131},{56,86,148},{82,86,97},
	{127,105,86},{140,146,154},{89,110,135},{71,53,50},{68,98,79},{115,10,39},{34,52,87},{100,13,27},{163,173,198},{105,88,83},
	{155,139,128},{98,11,28},{91,93,94},{98,68,40},{115,24,39},{27,55,109},{236,106,174},
}

--капты-----------------------------------------------------------------------------------------------------------
local point_guns_zone = {0,0, 0,0, 0,0}--1-идет ли захват, 2-номер зоны, 3-атакующие, 4-очки захвата, 5-защищающие, 6-очки захвата
local time_gz = 1*60
local time_guns_zone = time_gz
local name_mafia = {
	[0] = {createTeam("no", 255,255,255), {}},
	[1] = {createTeam("Grove Street Familes", 0,255,0), {105,106,107}},
	[2] = {createTeam("Vagos", 255,255,0), {108,109,110}},
	[3] = {createTeam("Ballas", 175,0,255), {102,103,104}},
	[4] = {createTeam("Rifa", 65,131,215), {173,174,175}},
	[5] = {createTeam("Varrios Los Aztecas", 137,196,244), {114,115,116}},
	[6] = {createTeam("Triads", 50,50,50), {117,118,120}},
	[7] = {createTeam("Da Nang Boys", 255,0,0), {121,122,123}},
	[8] = {createTeam("Russian Mafia", 100,100,100), {111,112,113}},
	[9] = {createTeam("Bikers", 150,75,0), {100,247,248,254}},
	[10] = {createTeam("Italian Mafia", 255,150,0), {124,125,126,127}},
}
for k,v in pairs(name_mafia) do
	setTeamFriendlyFire ( v[1], false )--false не могут убить союзников
end
local guns_zone = {}
------------------------------------------------------------------------------------------------------------------

--фракции---------------------------------------------------------------------------------------------------------
local fraction_table = {
	[1] = {createTeam("SAPD", color_mes.blue[1],color_mes.blue[2],color_mes.blue[3]), {64,75,87,265,266,267,280,281,282,283,284,285,288}},
}
for k,v in pairs(fraction_table) do
	setTeamFriendlyFire ( v[1], false )
end
------------------------------------------------------------------------------------------------------------------

-------------------пользовательские функции----------------------------------------------
function sendMessage(localPlayer, text, color)
	local time = getRealTime()
	local hour = time["hour"]
	local minute = time["minute"]
	local second = time["second"]

	if time["hour"] < 10 then
		hour = "0"..hour
	end

	if time["minute"] < 10 then
		minute = "0"..minute
	end

	if time["second"] < 10 then
		second = "0"..second
	end

	outputChatBox("["..hour..":"..minute..":"..second.."] "..text, localPlayer, color[1], color[2], color[3])
end

function earth_true(localPlayer)
	local playername = getPlayerName(localPlayer)
	set("earth_true", not get("earth_true"))
	admin_chat(localPlayer, "[ADMIN] "..playername.." ["..getElementData(localPlayer, "player_id").."] использовал function earth_true return "..tostring(get("earth_true")))
end
addEvent( "event_earth_true", true )
addEventHandler ( "event_earth_true", root, earth_true )

function destroyElement_fun( vehicleid )
	for k,v in pairs(getAttachedElements ( vehicleid )) do
		destroyElement(v)
	end

	destroyElement(vehicleid)
end
addEvent( "event_destroyElement", true )
addEventHandler ( "event_destroyElement", root, destroyElement_fun )

addEvent( "event_removePedFromVehicle", true )
addEventHandler ( "event_removePedFromVehicle", root, removePedFromVehicle )

addEvent( "event_setElementDimension", true )
addEventHandler ( "event_setElementDimension", root, setElementDimension )

function restart_res()
	local res = getResourceFromName ( "save_sql" )
	restartResource(res)
end
addEvent( "event_restartResource", true )
addEventHandler ( "event_restartResource", root, restart_res )

function player_position( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local x_table = split(x, ".")
	local y_table = split(y, ".")

	return x_table[1],y_table[1]
end

local car_shtraf_stoyanka = createColRectangle( 2054.1,2367.5, 62, 70 )
--[[local ls_airport = createColRectangle( 1364.041015625,-2766.3720703125, 789, 581 )
local lv_airport = createColRectangle( 1258.2685546875,1143.7607421875, 473, 719 )
local sf_airport = createColRectangle( -1734.609375,-695.794921875, 680, 1156 )]]
function isPointInCircle3D(x, y, z, x1, y1, z1, radius)
	if getDistanceBetweenPoints3D(x, y, z, x1, y1, z1) <= radius then
		return true
	else
		return false
	end
end

function isPointInCircle2D(x, y, x1, y1, radius)
	if getDistanceBetweenPoints2D(x, y, x1, y1) <= radius then
		return true
	else
		return false
	end
end

function getPlayerVehicle( localPlayer )
	local vehicle = getPedOccupiedVehicle ( localPlayer )
	return vehicle
end

function getSpeed(vehicle)
	if vehicle then
		local x, y, z = getElementVelocity(vehicle)
		return math.sqrt(math.pow(x, 2) + math.pow(y, 2) + math.pow(z, 2))*111.847*1.61--узнает скорость авто в км/ч
	end
end

function getVehicleNameFromPlate( number )
	local number = tostring(number)

	for i,vehicleid in pairs(getElementsByType("vehicle")) do
		local plate = getVehiclePlateText(vehicleid)
		if number == plate then
			return getVehicleNameFromModel(getElementModel(vehicleid))
		end
	end
end

function getVehicleidFromPlate( number )
	local number = tostring(number)

	for i,vehicleid in pairs(getElementsByType("vehicle")) do
		local plate = getVehiclePlateText(vehicleid)
		if number == plate then
			return vehicleid
		end
	end
end

math.randomseed(getTickCount())
function random(min, max)
	return math.random(min, max)
end

function me_chat(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, text, color_mes.pink)
		end
	end
end

function me_chat_player(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, "[ME] "..text, color_mes.pink)
		end
	end
end

function do_chat(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, text, color_mes.orange_do)
		end
	end
end

function do_chat_player(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, "[DO] "..text, color_mes.orange_do)
		end
	end
end

function b_chat_player(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, text, color_mes.gray)
		end
	end
end

function try_chat_player(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)
	local randomize = random(0,1)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			if randomize == 1 then
				sendMessage(player, "[TRY] "..text.." [УДАЧНО]", color_mes.green_try)
			else
				sendMessage(player, "[TRY] "..text.." [НЕУДАЧНО]", color_mes.red_try)
			end
		end
	end

	if randomize == 1 then
		return true
	else
		return false
	end
end

function ic_chat(localPlayer, text)
	local x,y,z = getElementPosition(localPlayer)

	for k,player in pairs(getElementsByType("player")) do
		local x1,y1,z1 = getElementPosition(player)

		if isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) then
			sendMessage(player, text, color_mes.white)
		end
	end
end

function admin_chat(localPlayer, text)
	for k,player in pairs(getElementsByType("player")) do
		local playername = getPlayerName(player)

		if search_inv_player_2_parameter(player, 44) ~= 0 and search_inv_player(player, 80, get("admin_chanel")) ~= 0 then
			sendMessage(player, text, color_mes.lyme)
		end
	end
end
addEvent("event_admin_chat", true)
addEventHandler("event_admin_chat", root, admin_chat)

function police_chat(localPlayer, text)
	for k,player in pairs(getElementsByType("player")) do
		local playername = getPlayerName(player)

		if search_inv_player_2_parameter(player, 10) ~= 0 and search_inv_player(player, 80, get("police_chanel")) ~= 0 then
			sendMessage(player, text, color_mes.blue)
		end
	end
end

function radio_chat(localPlayer, text, color)
	for k,player in pairs(getElementsByType("player")) do
		local playername = getPlayerName(player)

		if search_inv_player(player, 80, search_inv_player_2_parameter(localPlayer, 80)) ~= 0 then
			sendMessage(player, text, color)
		end
	end
end

function set_weather()
	local hour, minute = getTime()

	if hour == 0 and minute == 0 then
		setWeatherBlended(tomorrow_weather)

		tomorrow_weather = random(0,19)
		print("[tomorrow_weather] "..tomorrow_weather)

		setElementData(resourceRoot, "tomorrow_weather_data", tomorrow_weather)

		loto[1],loto[3] = random(1,1000),true
		print("[loto] "..loto[1])

		sendMessage(root, "[НОВОСТИ] Лотерея объявляется открытой, быстрее трите свои билеты", color_mes.green)

		timer_earth_clear()--очистка земли от предметов
	end
end

--[[Bone IDs:
1: глава
2: шея
3: позвоночник
4: таз
5: левой ключицы
6: правой ключице
7: левое плечо
8: правое плечо
9: левым локтем
10: правым локтем
11: левой рукой
12: правой рукой
13: левое бедро
14: правое бедро
15: левое колено
16: правое колено
17: левой лодыжке
18: правую лодыжку
19: левая нога
20: правая нога]]
function object_attach( localPlayer, model, bone, x,y,z, rx,ry,rz, time )--прикрепление объектов к игроку
	local x1, y1, z1 = getElementPosition (localPlayer)
	local objPick = createObject (model, x1, y1, z1)

	exports["bone_attach"]:attachElementToBone (objPick, localPlayer, bone, x,y,z, rx,ry,rz)
	setElementInterior(objPick, getElementInterior(localPlayer))
	setElementDimension(objPick, getElementDimension(localPlayer))

	setTimer(function ()
		destroyElement(objPick)
	end, time, 1)

	return objPick
end

--[[function string.split(input, separator)
	
	if type(input) ~= "string" then error("type mismatch in argument #1", 3) end
	if (separator and type(separator) ~= "string") then error("type mismatch in argument #2", 3) end

	if not separator then
		separator = "%s"
	end
	local t = {}
	local i = 1
	for str in string.gmatch(input, "([^"..separator.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end]]

function add_ped_in_no_ped_damage(ped)--добавление нпс
	table.insert(no_ped_damage, ped)
	setElementData(resourceRoot, "no_ped_damage", no_ped_damage)
end

function delet_ped_in_no_ped_damage(ped)--удаление нпс
	for k,v in pairs(no_ped_damage) do
		if v == ped then
			table.remove(no_ped_damage, k)
			break
		end
	end
	setElementData(resourceRoot, "no_ped_damage", no_ped_damage)
end
-----------------------------------------------------------------------------------------

local info_png = {
	[0] = {"", ""},
	[1] = {"чековая книжка", "$ в банке"},
	[2] = {"права", "номер"},
	[3] = {"сигареты Big Break Red", "сигарет"},
	[4] = {"аптечка", "шт"},
	[5] = {"канистра с", "лит."},
	[6] = {"ключ от т/с под номером", ""},
	[7] = {"сигареты Big Break Blue", "сигарет"},
	[8] = {"сигареты Big Break White", "сигарет"},
	[9] = {"Граната", "боеприпасов"},
	[10] = {"полицейский жетон", "номер"},
	[11] = {"планшет", "шт"},
	[12] = {"Кольт-45", "боеприпасов"},
	[13] = {"Дигл", "боеприпасов"},
	[14] = {"AK-47", "боеприпасов"},
	[15] = {"M4", "боеприпасов"},
	[16] = {"уголь", "кг"},
	[17] = {"МП5", "боеприпасов"},
	[18] = {"Узи", "боеприпасов"},
	[19] = {"Слезоточивый газ", "боеприпасов"},
	[20] = {"наркотики", "гр"},
	[21] = {"пиво старый эмпайр", "шт"},
	[22] = {"пиво штольц", "шт"},
	[23] = {"ремонтный набор", "шт"},
	[24] = {"ящик с товаром", "$ за штуку"},
	[25] = {"ключ от дома под номером", ""},
	[26] = {"Кольт-45 с глушителем", "боеприпасов"},
	[27] = {"одежда", ""},
	[28] = {"тушка оленя", "$ за штуку"},
	[29] = {"охотничий рожок", "%"},
	[30] = {"нож мясника", "шт"},
	[31] = {"пицца", "$ за штуку"},
	[32] = {"потерянный груз", "$ за штуку"},
	[33] = {"сонар", "%"},
	[34] = {"Дробовик", "боеприпасов"},
	[35] = {"парашют", "шт"},
	[36] = {"дубинка", "шт"},
	[37] = {"бита", "шт"},
	[38] = {"нож", "шт"},
	[39] = {"бронежилет", "шт"},
	[40] = {"лом", "%"},
	[41] = {"Винтовка", "боеприпасов"},
	[42] = {"таблетки от наркозависимости", "шт"},
	[43] = {"документы на бизнес под номером", ""},
	[44] = {"админский жетон", "ранг"},
	[45] = {"риэлторская лицензия", "шт"},
	[46] = {"радар", "шт"},
	[47] = {"перцовый балончик", "мл"},
	[48] = {"мясо", "$ за штуку"},
	[49] = {"лопата", "шт"},
	[50] = {"лицензия на оружие", "номер"},
	[51] = {"jetpack", "шт"},
	[52] = {"кислородный балон на 5 мин", "шт"},
	[53] = {"бургер", "шт"},
	[54] = {"пицца", "шт"},
	[55] = {"мыло", "%"},
	[56] = {"пижама", "%"},
	[57] = {"алкотестер", "шт"},
	[58] = {"наркотестер", "шт"},
	[59] = {"квитанция для оплаты дома на", "дней"},
	[60] = {"квитанция для оплаты бизнеса на", "дней"},
	[61] = {"квитанция для оплаты т/с на", "дней"},
	[62] = {"коробка с продуктами", "$ за штуку"},
	[63] = {"GPS навигатор", "шт"},
	[64] = {"лицензия на работу", "вид работы"},
	[65] = {"инкассаторская сумка", "$ в сумке"},
	[66] = {"ящик с оружием", "$ за штуку"},
	[67] = {"бензопила", "шт"},
	[68] = {"дрова", "кг"},
	[69] = {"пустая коробка", "шт"},
	[70] = {"кирка", "шт"},
	[71] = {"железная руда", "кг"},
	[72] = {"виски", "шт"},
	[73] = {"бочка с нефтью", "$ за штуку"},
	[74] = {"#1 маршрутный лист", "ост."},
	[75] = {"мусор", "кг"},
	[76] = {"антипохмелин", "шт"},
	[77] = {"проездной билет", "шт"},
	[78] = {"рыба", "кг"},
	[79] = {"банковский чек на", "$"},
	[80] = {"рация", "канал"},
	[81] = {"динамит", "шт"},
	[82] = {"шнур", "шт"},
	[83] = {"тратил", "гр"},
	[84] = {"отмычка", "%"},
	[85] = {"повязка", "опг"},
	[86] = {"документы на скотобойню под номером", ""},
	[87] = {"трудовой договор забойщика скота на", "скотобойне"},
	[88] = {"тушка коровы", "$ за штуку"},
	[89] = {"мешок с кормом", "$ за штуку"},
	[90] = {"колба", "реагент"},
	[91] = {"ордер на обыск", "", "гражданина", "т/с", "дома"},
	[92] = {"наручники", "шт"},
	[93] = {"колода карт", "шт"},
	[94] = {"квадрокоптер", "шт"},
	[95] = {"двигатель", "stage"},
	[96] = {"колесо", "марка"},
	[97] = {"краска для т/с", "цвет"},
	[98] = {"фара", "цвет"},
	[99] = {"винилы", "вариант"},
	[100] = {"гидравлика", "шт"},
	[101] = {"краска для колес", "цвет"},
	[102] = {"уголовное дело", "преступлений"},
	[103] = {"водка сталкер", "шт"},
	[104] = {"лотерейный билет под номером", ""},
	[105] = {"паспорт", "номер"},
	[106] = {"документы на дом под номером", ""},
	[107] = {"документы на т/с под номером", ""},
	[108] = {"пустой бланк", "шт"},
	[109] = {"заявление на пропажу т/с под номером", ""},
	[110] = {"тыквенный пирог", "$ за штуку"},
	[111] = {"тыква", "шт"},
	[112] = {"семена тыквы", "шт"},
	[113] = {"лейка", "%"},
	[114] = {"тесто", "шт"},
	[115] = {"ящик под номером", ""},
	[116] = {"ключ от ящика под номером", ""},
}

local craft_table = {--[предмет 1, рецепт 2, предметы для крафта 3, кол-во предметов для крафта 4, предмет который скрафтится 5]
	{"", "", "82,83", "1,100", "81,1"},
	{"", "", "90,90", "3,78", "20,1"},
	{"", "", "111,114", "1,1", "110,250"},
}

for i,v in ipairs(craft_table) do
	craft_table[i][1] = info_png[tonumber(split(v[5], ",")[1])][1].." "..split(v[5], ",")[2].." "..info_png[tonumber(split(v[5], ",")[1])][2]
	craft_table[i][2] = info_png[tonumber(split(v[3], ",")[1])][1].." "..split(v[4], ",")[1].." "..info_png[tonumber(split(v[3], ",")[1])][2].." + "..info_png[tonumber(split(v[3], ",")[2])][1].." "..split(v[4], ",")[2].." "..info_png[tonumber(split(v[3], ",")[2])][2]
end

local quest_table = {--1 название, 2 описание, 3 кол-во, 5 предмет засчитывания, 6 награда $, 7 награда предметом, 8 массив имен кто выполнил квест
	[1] = {"Мясник", "Обработать ", math.random(5,10), " кусков мяса", 48, math.random(1000,5000), {79,10000}, {}},
	[2] = {"Рудокоп", "Добыть ", math.random(5,10), " раз железную руду", 71, math.random(1000,5000), {0,0}, {}},
	[3] = {"Нефтебарон", "Перевезти ", math.random(1,2), " раз бочки с нефтью", 73, math.random(1000,5000), {5,25}, {}},
}

--фермы
local harvest = {}--растения игроков
local harvest_time = {--время роста в минутах 1, защита мин, сокращение роста после полива 3, ид объекта 4, ид предмета 5
	[112] = {5, 1, 0, 811, 111},
}
for k,v in pairs(harvest_time) do
	harvest_time[k][3] = tonumber(split(tostring(v[1]*0.5), ".")[1])
end
local harvest_icon_complete = 2228

local weapon = {
	[9] = {info_png[9][1], 16, 360, 5},
	[12] = {info_png[12][1], 22, 240, 25},
	[13] = {info_png[13][1], 24, 1440, 25},
	[14] = {info_png[14][1], 30, 4200, 25},
	[15] = {info_png[15][1], 31, 5400, 25},
	[17] = {info_png[17][1], 29, 2400, 25},
	[18] = {info_png[18][1], 28, 600, 25},
	[19] = {info_png[19][1], 17, 360, 5},
	[26] = {info_png[26][1], 23, 720, 25},
	[34] = {info_png[34][1], 25, 720, 25},
	[35] = {info_png[35][1], 46, 200, 1},
	[36] = {info_png[36][1], 3, 150, 1},
	[37] = {info_png[37][1], 5, 150, 1},
	[38] = {info_png[38][1], 4, 150, 1},
	[41] = {info_png[41][1], 33, 6000, 25},
	[47] = {info_png[47][1], 41, 50, 25},
	[49] = {info_png[49][1], 6, 50, 1},
}

local weapon_shop = {
	--[9] = {info_png[9][1], 16, 360, 5},
	[12] = {info_png[12][1], 22, 240, 25},
	[13] = {info_png[13][1], 24, 1440, 25},
	[14] = {info_png[14][1], 30, 4200, 25},
	[15] = {info_png[15][1], 31, 5400, 25},
	[17] = {info_png[17][1], 29, 2400, 25},
	[18] = {info_png[18][1], 28, 600, 25},
	--[19] = {info_png[19][1], 17, 360, 5},
	[26] = {info_png[26][1], 23, 720, 25},
	[34] = {info_png[34][1], 25, 720, 25},
	[35] = {info_png[35][1], 46, 200, 1},
	--[36] = {info_png[36][1], 3, 150, 1},
	[37] = {info_png[37][1], 5, 150, 1},
	[38] = {info_png[38][1], 4, 150, 1},
	[41] = {info_png[41][1], 33, 6000, 25},
	--[47] = {info_png[47][1], 41, 50, 25},
	[49] = {info_png[49][1], 6, 50, 1},
}

local shop = {
	[3] = {info_png[3][1], 20, 5},
	[4] = {info_png[4][1], 1, 250},
	[7] = {info_png[7][1], 20, 10},
	[8] = {info_png[8][1], 20, 15},
	[11] = {info_png[11][1], 1, 100},
	[21] = {info_png[21][1], 1, 45},
	[22] = {info_png[22][1], 1, 60},
	[23] = {info_png[23][1], 1, 100},
	[29] = {info_png[29][1], 100, 500},
	[33] = {info_png[33][1], 100, 500},
	[40] = {info_png[40][1], 10, 500},
	[42] = {info_png[42][1], 1, 5000},
	[46] = {info_png[46][1], 1, 100},
	[47] = {info_png[47][1], 500, 50},
	[52] = {info_png[52][1], 1, 1000},
	[53] = {info_png[53][1], 1, 100},
	[54] = {info_png[54][1], 1, 50},
	[55] = {info_png[55][1], 100, 50},
	[56] = {info_png[56][1], 100, 100},
	[63] = {info_png[63][1], 1, 100},
	[72] = {info_png[72][1], 1, 500},
	[76] = {info_png[76][1], 1, 250},
	[80] = {info_png[80][1], 10, 500},
	[93] = {info_png[93][1], 1, 50},
	[94] = {info_png[94][1], 1, 5000},
	[103] = {info_png[103][1], 1, 250},
	[104] = {info_png[104][1], 0, 100},
	[112] = {info_png[112][1], 10, 100},
	[113] = {info_png[113][1], 100, 500},
	[114] = {info_png[114][1], 1, 200},
	[115] = {info_png[115][1], 0, 2500},
}

local repair_shop = {
	{info_png[95][1].." 0 "..info_png[95][2], 0, 0.5, 95},
	{info_png[95][1].." 1 "..info_png[95][2], 1, 1, 95},
	{info_png[95][1].." 2 "..info_png[95][2], 2, 2, 95},
	{info_png[95][1].." 3 "..info_png[95][2], 3, 3, 95},
	{info_png[99][1].." 0 "..info_png[99][2], 0, 0.1, 99},
	{info_png[99][1].." 1 "..info_png[99][2], 1, 0.1, 99},
	{info_png[99][1].." 2 "..info_png[99][2], 2, 0.1, 99},
	{info_png[99][1].." 3 "..info_png[99][2], 3, 0.1, 99},
	{info_png[100][1], 1, 1, 100},
	{info_png[96][1].." 1025 "..info_png[96][2], 1025, 0.4, 96},
	{info_png[96][1].." 1073 "..info_png[96][2], 1073, 0.4, 96},
	{info_png[96][1].." 1074 "..info_png[96][2], 1074, 0.4, 96},
	{info_png[96][1].." 1075 "..info_png[96][2], 1075, 0.4, 96},
	{info_png[96][1].." 1076 "..info_png[96][2], 1076, 0.4, 96},
	{info_png[96][1].." 1077 "..info_png[96][2], 1077, 0.4, 96},
	{info_png[96][1].." 1078 "..info_png[96][2], 1078, 0.4, 96},
	{info_png[96][1].." 1079 "..info_png[96][2], 1079, 0.4, 96},
	{info_png[96][1].." 1080 "..info_png[96][2], 1080, 0.4, 96},
	{info_png[96][1].." 1081 "..info_png[96][2], 1081, 0.4, 96},
	{info_png[96][1].." 1082 "..info_png[96][2], 1082, 0.4, 96},
	{info_png[96][1].." 1083 "..info_png[96][2], 1083, 0.4, 96},
	{info_png[96][1].." 1084 "..info_png[96][2], 1084, 0.4, 96},
	{info_png[96][1].." 1085 "..info_png[96][2], 1085, 0.4, 96},
	{info_png[96][1].." 1096 "..info_png[96][2], 1096, 0.4, 96},
	{info_png[96][1].." 1097 "..info_png[96][2], 1097, 0.4, 96},
	{info_png[96][1].." 1098 "..info_png[96][2], 1098, 0.4, 96},
}

for k,v in ipairs(color_table) do
	table.insert(repair_shop, {info_png[97][1].." "..k.." "..info_png[97][2], k, 0.05, 97})
end

for k,v in ipairs(color_table) do
	table.insert(repair_shop, {info_png[101][1].." "..k.." "..info_png[101][2], k, 0.05, 101})
end

for k,v in ipairs(color_table) do
	table.insert(repair_shop, {info_png[98][1].." "..k.." "..info_png[98][2], k, 0.05, 98})
end

local gas = {
	[5] = {info_png[5][1].." 25 "..info_png[5][2], 25, 250},
	[23] = {info_png[23][1], 1, 100},
}

local giuseppe = {
	{info_png[64][1].." Угонщик", 6, 5000, 64},
	{info_png[64][1].." Киллер", 20, 5000, 64},
	{info_png[83][1], 100, 1000, 83},
	{info_png[84][1], 10, 500, 84},
	{info_png[85][1].." "..getTeamName (name_mafia[1][1]), 1, 5000, 85},--5
	{info_png[85][1].." "..getTeamName (name_mafia[2][1]), 2, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[3][1]), 3, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[4][1]), 4, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[5][1]), 5, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[6][1]), 6, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[7][1]), 7, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[8][1]), 8, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[9][1]), 9, 5000, 85},
	{info_png[85][1].." "..getTeamName (name_mafia[10][1]), 10, 5000, 85},--14
	{info_png[90][1].." 78 "..info_png[90][2], 78, 1000, 90},
}

local mayoralty_shop = {
	{info_png[2][1], 1, 1000, 2},
	{info_png[10][1], 1, 50000, 10},
	{info_png[50][1], 1, 10000, 50},
	{info_png[64][1].." Таксист", 1, 5000, 64},
	{info_png[64][1].." Мусоровозчик", 2, 5000, 64},
	{info_png[64][1].." Инкассатор", 3, 5000, 64},
	{info_png[64][1].." Рыболов", 4, 5000, 64},
	{info_png[64][1].." Пилот", 5, 5000, 64},
	{info_png[64][1].." Дальнобойщик", 7, 5000, 64},
	{info_png[64][1].." Перевозчик оружия", 8, 5000, 64},
	{info_png[64][1].." Водитель автобуса", 9, 5000, 64},
	{info_png[64][1].." Парамедик", 10, 5000, 64},
	{info_png[64][1].." Уборщик улиц", 11, 5000, 64},
	{info_png[64][1].." Пожарный", 12, 5000, 64},
	{info_png[64][1].." SWAT", 13, 5000, 64},
	--{info_png[64][1].." Фермер", 14, 5000, 64},
	{info_png[64][1].." Охотник", 15, 5000, 64},
	{info_png[64][1].." Развозчик пиццы", 16, 5000, 64},
	{info_png[64][1].." Уборщик морского дна", 17, 5000, 64},
	{info_png[64][1].." Транспортный детектив", 18, 5000, 64},
	{info_png[64][1].." Спасатель", 19, 5000, 64},
	{info_png[77][1], 100, 100, 77},

	{"квитанция для оплаты дома на "..get("day_taxation").." дней", get("day_taxation"), (get("zakon_taxation_house")*get("day_taxation")), 59},
	{"квитанция для оплаты бизнеса на "..get("day_taxation").." дней", get("day_taxation"), (get("zakon_taxation_business")*get("day_taxation")), 60},
	{"квитанция для оплаты т/с на "..get("day_taxation").." дней", get("day_taxation"), (get("zakon_taxation_car")*get("day_taxation")), 61},
}

local weapon_cops = {
	[9] = {info_png[9][1], 16, 360, 5},
	[12] = {info_png[12][1], 22, 240, 25},
	[15] = {info_png[15][1], 31, 5400, 25},
	[17] = {info_png[17][1], 29, 2400, 25},
	[19] = {info_png[19][1], 17, 360, 5},
	[34] = {info_png[34][1], 25, 720, 25},
	[36] = {info_png[36][1], 3, 150, 1},
	[41] = {info_png[41][1], 34, 6000, 25},
	[47] = {info_png[47][1], 41, 50, 25},
	[39] = {info_png[39][1], 39, 50, 1},
}

local sub_cops = {
	{info_png[57][1], 1, 57},
	{info_png[58][1], 1, 58},
	{info_png[108][1], 1, 108},
}

local deathReasons = {
	[19] = "Rocket",
	[37] = "Burnt",
	[49] = "Rammed",
	[50] = "Ranover/Helicopter Blades",
	[51] = "Explosion",
	[52] = "Driveby",
	[53] = "Drowned",
	[54] = "Fall",
	[55] = "Unknown",
	[56] = "Melee",
	[57] = "Weapon",
	[59] = "Tank Grenade",
	[63] = "Blown"
}

local interior = {
	{1, "Ammu-nation 1",	285.7870,	-41.7190,	1001.5160},
	{1, "Burglary House 1",	224.6351,	1289.012,	1082.141},
	{1, "Caligulas Casino",	2235.2524,	1708.5146,	1010.6129},
	{1, "Denise's Place",	244.0892,	304.8456,	999.1484},--комната со срачем
	{1, "Shamal cabin",	1.6127,	34.7411,	1199.0},
	{1, "Safe House 4",	2216.5400,	-1076.2900,	1050.4840},--комната в отеле
	{1, "Sindacco Abatoir",	963.6078,	2108.3970,	1011.0300},--мясокомбинат
	{1, "Sub Urban",	203.8173,	-46.5385,	1001.8050},--магаз одежды
	{1, "Wu Zi Mu's Betting place",	-2159.9260,	641.4587,	1052.3820},--9 бук-ая контора с комнатой

	{2, "Ryder's House",	2464.2110,	-1697.9520,	1013.5080},
	{2, "The Pig Pen",	1213.4330,	-6.6830,	1000.9220},--стриптиз бар
	{2, "Big Smoke's Crack Palace",	2570.33,	-1302.31,	1044.12},--хата биг смоука
	{2, "Burglary House 2",	225.756,	1240.000,	1082.149},
	{2, "Burglary House 3",	447.470,	1398.348,	1084.305},
	{2, "Burglary House 4",	491.740,	1400.541,	1080.265},
	{2, "Katie's Place	", 267.2290,	304.7100,	999.1480},--16 комната

	{3, "Jizzy's Pleasure Domes",	-2636.7190,	1402.9170,	906.4609},--стриптиз бар
	{3, "Bike School",	1494.3350,	1305.6510,	1093.2890},
	{3, "Big Spread Ranch",	1210.2570,	-29.2986,	1000.8790},--стриптиз бар
	{3, "LV Tattoo Parlour",	-204.4390,	-43.6520,	1002.2990},
	{3, "LVPD HQ",	289.7703,	171.7460,	1007.1790},
	{3, "Pro-Laps",	207.3560,	-138.0029,	1003.3130},--магаз одежды
	{3, "Las Venturas Planning Dep.",	374.6708,	173.8050,	1008.3893},--мэрия
	{3, "Driving School",	-2027.9200,	-105.1830,	1035.1720},
	{3, "Johnson House",	2496.0500,	-1693.9260,	1014.7420},
	{3, "Burglary House 5",	234.733,	1190.391,	1080.258},
	{3, "Gay Gordo's Barbershop",	418.6530,	-82.6390,	1001.8050},--парик-ая
	{3, "Helena's Place",	292.4459,	308.7790,	999.1484},--амбар
	{3, "Inside Track Betting",	826.8863,	5.5091,	1004.4830},--букм-ая контора 2
	{3, "Sex Shop",	-106.7268,	-19.6444,	1000.7190},--30

	{4, "24/7 shop 1",	-27.3769,	-27.6416,	1003.5570},
	{4, "Ammu-Nation 2",	285.8000,	-84.5470,	1001.5390},
	{4, "Burglary House 6",	-262.91,	1454.966,	1084.367},
	{4, "Burglary House 7",	221.4296,	1142.423,	1082.609},
	{4, "Burglary House 8",	261.1168,	1286.519,	1080.258},
	{4, "Diner 2",	460.0,	-88.43,	999.62},
	{4, "Dirtbike Stadium",	-1435.8690,	-662.2505,	1052.4650},
	{4, "Michelle's Place",	302.6404,	304.8048,	999.1484},--38 странная хата, на одном сервере это пж-ая часть)

	{5, "Madd Dogg's Mansion",	1298.9116,	-795.9028,	1084.5097},--огромный особняк
	{5, "Well Stacked Pizza Co.",	377.7758,	-126.2766,	1001.4920},
	{5, "Victim",	225.3310,	-8.6169,	1002.1977},--магаз одежды
	{5, "Burglary House 9",	22.79996,	1404.642,	1084.43},
	{5, "Burglary House 10",	228.9003,	1114.477,	1080.992},
	{5, "Burglary House 11",	140.5631,	1369.051,	1083.864},
	{5, "The Crack Den",	322.1117,	1119.3270,	1083.8830},--наркопритон
	{5, "Police Station (Barbara's)",	322.72,	306.43,	999.15},
	{5, "Ganton Gym",	768.0793,	5.8606,	1000.7160},--тренажорка
	{5, "Vank Hoff Hotel",	2232.8210,	-1110.0180,	1050.8830},--48 комната в отеле

	{6, "Ammu-Nation 3",	297.4460,	-109.9680,	1001.5160},
	{6, "Ammu-Nation 4",	317.2380,	-168.0520,	999.5930},--инт для военного склада
	{6, "LSPD HQ",	246.4510,	65.5860,	1003.6410},
	{6, "Safe House 3",	2333.0330,	-1073.9600,	1049.0230},
	{6, "Safe House 5",	2194.2910,	-1204.0150,	1049.0230},
	{6, "Safe House 6",	2308.8710,	-1210.7170,	1049.0230},
	{6, "Cobra Marital Arts Gym",	774.0870,	-47.9830,	1000.5860},--тренажорка
	{6, "24/7 shop 2",	-26.7180,	-55.9860,	1003.5470},--буду юзать это инт
	{6, "Millie's Bedroom",	344.5200,	304.8210,	999.1480},--плохая комната)
	{6, "Fanny Batter's Brothel",	744.2710,	1437.2530,	1102.7030},
	{6, "Burglary House 15",	234.319,	1066.455,	1084.208},
	{6, "Burglary House 16",	-69.049,	1354.056,	1080.211},--60

	{7, "Ammu-Nation 5 (2 Floors)",	315.3850,	-142.2420,	999.6010},
	{7, "8-Track Stadium", -1417.8720,	-276.4260,	1051.1910},
	{7, "Below the Belt Gym",	774.2430,	-76.0090,	1000.6540},--63 тренажорка

	{8, "Colonel Fuhrberger's House",	2807.8990,	-1172.9210,	1025.5700},--дом с пушкой
	{8, "Burglary House 22",	-42.490,	1407.644,	1084.43},--65

	{9, "Burglary House 12",	85.32596,	1323.585,	1083.859},
	{9, "Burglary House 13",	260.3189,	1239.663,	1084.258},
	{9, "Cluckin' Bell",	365.67,	-11.61,	1001.87},--68

	{10, "Four Dragons Casino",	2009.4140,	1017.8990,	994.4680},
	{10, "RC Zero's Battlefield",	-975.5766,	1061.1312,	1345.6719},
	{10, "Burger Shot",	366.4220,	-73.4700,	1001.5080},
	{10, "Burglary House 14",	21.241,	1342.153,	1084.375},
	{10, "Hashbury safe house",	2264.5231,	-1210.5229,	1049.0234},
	{10, "24/7 shop 3",	6.0780,	-28.6330,	1003.5490},
	{10, "Abandoned AC Tower",	419.6140,	2536.6030,	10.0000},
	{10, "SFPD HQ",	246.4410,	112.1640,	1003.2190},--76

	{11, "Ten Green Bottles Bar",	502.3310,	-70.6820,	998.7570},--77

	{12, "The Casino", 1132.9450,	-8.6750,	1000.6800},
	{12, "Macisla's Barbershop",	411.6410,	-51.8460,	1001.8980},--парик-ая
	{12, "Modern safe house",	2324.4990,	-1147.0710,	1050.7100},--80

	{14, "Kickstart Stadium",	-1464.5360,	1557.6900,	1052.5310},
	{14, "Didier Sachs",	204.1789,	-165.8740,	1000.5230},--82 --магаз одежды

	{15, "Binco",	207.5430,	-109.0040,	1005.1330},--магаз одежды
	{15, "Blood Bowl Stadium",	-1394.20,	987.62,	1023.96},--дерби арена
	{15, "Jefferson Motel",	2217.6250,	-1150.6580,	1025.7970},
	{15, "Burglary House 18",	327.808,	1479.74,	1084.438},
	{15, "Burglary House 19",	375.572,	1417.439,	1081.328},
	{15, "Burglary House 20",	384.644,	1471.479,	1080.195},
	{15, "Burglary House 21",	295.467,	1474.697,	1080.258},--89

	{16, "24/7 shop 4",	-25.3730,	-139.6540,	1003.5470},
	{16, "LS Tattoo Parlour",	-204.5580,	-25.6970,	1002.2730},
	{16, "Sumoring? stadium",	-1400,	1250,	1040},--92

	{17, "24/7 shop 5",	-25.3930,	-185.9110,	1003.5470},
	{17, "Club",	493.4687,	-23.0080,	1000.6796},
	{17, "Rusty Brown's - Ring Donuts",	377.0030,	-192.5070,	1000.6330},--кафешка
	{17, "The Sherman's Dam Generator Hall",	-942.1320,	1849.1420,	5.0050},--96 дамба

	{18, "Lil Probe Inn",	-227.0280,	1401.2290,	27.7690},--бар
	{18, "24/7 shop 6",	-30.9460,	-89.6090,	1003.5490},
	{18, "Atrium",	1726.1370,	-1645.2300,	20.2260},--отель
	{18, "Warehouse 2",	1296.6310,	0.5920,	1001.0230},
	{18, "Zip",	161.4620,	-91.3940,	1001.8050},--101 магаз одежды
}

local cash_car = {
	[400] = {"LANDSTAL", 25000},
	[401] = {"BRAVURA", 9000},
	[402] = {"BUFFALO", 35000},
	[403] = {"LINERUN", 35000},
	[404] = {"PEREN", 10000},
	[405] = {"SENTINEL", 35000},
	--[406] = {"DUMPER", 50000},--самосвал
	--[407] = {"FIRETRUK", 45000},
	--[408] = {"TRASH", 35000},--мусоровоз
	[409] = {"STRETCH", 40000},--лимузин
	[410] = {"MANANA", 9000},
	[411] = {"INFERNUS", 95000},
	[412] = {"VOODOO", 30000},
	[413] = {"PONY", 20000},--грузовик с колонками
	--[414] = {"MULE", 22000},--грузовик развозчика
	[415] = {"CHEETAH", 105000},
	--[416] = {"AMBULAN", 30000},--скорая
	[418] = {"MOONBEAM", 16000},
	[419] = {"ESPERANT", 19000},
	--[420] = {"TAXI", 20000},
	[421] = {"WASHING", 18000},
	[422] = {"BOBCAT", 26000},
	--[423] = {"MRWHOOP", 29000},--грузовик мороженого
	[424] = {"BFINJECT", 15000},
	[426] = {"PREMIER", 25000},
	--[428] = {"SECURICA", 40000},--инкассаторский грузовик
	[429] = {"BANSHEE", 45000},
	--[431] = {"BUS", 15000},
	--[432] = {"RHINO", 110000},--танк
	--[433] = {"BARRACKS", 10000},--военный грузовик
	[434] = {"HOTKNIFE", 35000},
	[436] = {"PREVION", 9000},
	--[437] = {"COACH", 20000},--автобус
	--[438] = {"CABBIE", 10000},--такси
	[439] = {"STALLION", 19000},
	[440] = {"RUMPO", 26000},--грузовик развозчика в сампрп
	--[442] = {"ROMERO", 10000},--гробовозка
	--[443] = {"PACKER", 20000},--фура с траплином
	[444] = {"MONSTER", 40000},
	[445] = {"ADMIRAL", 35000},
	[451] = {"TURISMO", 95000},
	[455] = {"FLATBED", 10000},--пустой грузовик
	--[456] = {"YANKEE", 5000},--грузовик
	--[457] = {"CADDY", 9000},--гольфкар
	[458] = {"SOLAIR", 18000},
	[459] = {"TOPFUN", 20000},--грузовик с игру-ми машинами
	[466] = {"GLENDALE", 20000},
	[467] = {"OCEANIC", 20000},
	--[470] = {"PATRIOT", 40000},--военный хамер
	[471] = {"QUADBIKE", 9000},--квадроцикл
	[474] = {"HERMES", 19000},
	[475] = {"SABRE", 19000},
	[477] = {"ZR350", 45000},
	[478] = {"WALTON", 26000},
	[479] = {"REGINA", 18000},
	[480] = {"COMET", 35000},
	[482] = {"BURRITO", 26000},
	[483] = {"CAMPER", 26000},
	--[485] = {"BAGGAGE", 9000},--погрузчик багажа
	--[486] = {"DOZER", 50000},--бульдозер
	[489] = {"RANCHER", 40000},
	[491] = {"VIRGO", 9000},
	[492] = {"GREENWOO", 19000},
	[494] = {"HOTRING", 145000},--гоночная
	[495] = {"SANDKING", 40000},
	[496] = {"BLISTAC", 35000},
	[498] = {"BOXVILLE", 22000},
	[499] = {"BENSON", 22000},
	[500] = {"MESA", 25000},
	[502] = {"Hotring Racer 2", 145000},--гоночная
	[503] = {"Hotring Racer 3", 145000},--гоночная
	[504] = {"BLOODRA", 45000},--дерби тачка
	[506] = {"SUPERGT", 105000},
	[507] = {"ELEGANT", 35000},
	[508] = {"JOURNEY", 22000},
	--[514] = {"Tanker", 30000},--тягач
	--[515] = {"RDTRAIN", 35000},--тягач
	[516] = {"NEBULA", 35000},
	[517] = {"MAJESTIC", 35000},
	[518] = {"BUCCANEE", 19000},
	--[524] = {"CEMENT", 50000},
	[526] = {"FORTUNE", 19000},
	[527] = {"CADRONA", 9000},
	[529] = {"WILLARD", 19000},
	--[530] = {"FORKLIFT", 9000},--вилочный погр-ик
	--[531] = {"TRACTOR", 9000},
	--[532] = {"COMBINE", 10000},
	[533] = {"FELTZER", 35000},
	[534] = {"REMINGTN", 30000},
	[535] = {"SLAMVAN", 19000},
	[536] = {"BLADE", 19000},
	[540] = {"VINCENT", 19000},
	[541] = {"BULLET", 105000},
	[542] = {"CLOVER", 19000},
	[543] = {"SADLER", 26000},
	--[544] = {"Fire Truck", 15000},--с лестницей
	[545] = {"HUSTLER", 20000},
	[546] = {"INTRUDER", 19000},
	[547] = {"PRIMO", 19000},
	[549] = {"TAMPA", 19000},
	[550] = {"SUNRISE", 19000},
	[551] = {"MERIT", 35000},
	--[552] = {"UTILITY", 20000},--санитарный фургон
	[554] = {"YOSEMITE", 40000},
	[555] = {"WINDSOR", 35000},
	[556] = {"Monster 2", 40000},
	[557] = {"Monster 3", 40000},
	[558] = {"URANUS", 35000},
	[559] = {"JESTER", 35000},
	[560] = {"SULTAN", 35000},
	[561] = {"STRATUM", 35000},
	[562] = {"ELEGY", 35000},
	[565] = {"FLASH", 35000},
	[566] = {"TAHOMA", 35000},
	[567] = {"SAVANNA", 19000},
	[568] = {"BANDITO", 15000},
	--[571] = {"KART", 15000},
	--[572] = {"MOWER", 15000},--газонокосилка
	[573] = {"DUNE", 40000},
	--[574] = {"SWEEPER", 15000},--очистка улиц
	[575] = {"BROADWAY", 19000},
	[576] = {"TORNADO", 19000},
	--[578] = {"DFT30", 5000},--3 колесная тачка
	[579] = {"HUNTLEY", 40000},
	[580] = {"STAFFORD", 35000},
	--[582] = {"NEWSVAN", 20000},--фургон новостей
	--[583] = {"TUG", 15000},--буксир
	--[584] = {"PETROTR", 35000},--трейлер бензина
	[585] = {"EMPEROR", 35000},
	[587] = {"EUROS", 35000},
	--[588] = {"HOTDOG", 22000},
	[589] = {"CLUB", 35000},
	[600] = {"PICADOR", 26000},
	[602] = {"ALPHA", 35000},
	[603] = {"PHOENIX", 35000},
	[604] = {"Damaged Glendale", 5000},
	[605] = {"Damaged Sadler", 5000},

	--тачки копов
	--[596] = {"Police LS", 2500},
	--[597] = {"Police SF", 2500},
	--[598] = {"Police LV", 2500},
	--[599] = {"Police Ranger", 2500},
	--[427] = {"ENFORCER", 40000},--пол-ий грузовик
	--[601] = {"S.W.A.T.", 40000},
	--[490] = {"FBIRANCH", 40000},
	--[525] = {"TOWTRUCK", 20000},--эвакуатор для копов
	--[523] = {"HPV1000", 2000},--мотик полиции
	--[528] = {"FBITRUCK", 40000},

	--bikes
	[586] = {"WAYFARER", 10000},
	[468] = {"Sanchez", 15000},
	--[448] = {"Pizza Boy", 1000},
	[461] = {"PCJ-600", 20000},
	[521] = {"FCR900", 20000},
	[522] = {"NRG500", 90000},
	[462] = {"Faggio", 1000},
	[463] = {"FREEWAY", 10000},
	[581] = {"BF400", 20000},
}

local cash_boats = {
	--[472] = {"COASTGRD", 10000},--лодка берег-ой охраны
	[473] = {"DINGHY", 5000},--моторная лодка
	[493] = {"Jetmax", 60000},--лодка
	--[595] = {"LAUNCH", 30000},--военная лодка
	[484] = {"MARQUIS", 99000},--яхта с парусом
	--[430] = {"PREDATOR", 40000},--поли-ая лодка
	[452] = {"SPEEDER", 30000},--лодка
	--[453] = {"REEFER", 25000},--рыболовное судно
	[454] = {"TROPIC", 73000},--яхта
	[446] = {"SQUALO", 60000},--лодка
	[539] = {"VORTEX", 26000},--возд-ая подушка
}

local cash_helicopters = {
	--[[[548] = {"CARGOBOB", 25000},
	[425] = {"HUNTER", 99000},--верт военный с ракетами
	[417] = {"LEVIATHN", 25000},--верт военный
	[488] = {"News Chopper", 45000},--верт новостей
	[469] = {"SPARROW", 25000},--верт без пушки
	[447] = {"SEASPAR", 28000},--верт с пуляметом]]
	--[497] = {"Police Maverick", 45000},
	[519] = {"SHAMAL", 45000},
	[487] = {"MAVERICK", 45000},--верт
	--[553] = {"NEVADA", 45000},--самолет
	--[593] = {"DODO", 45000},
	--[563] = {"RAINDANC", 49000},--верт спасателей
}

local cash_airplanes = {
	[592] = {"ANDROM", 45000},--андромада
	[577] = {"AT400", 45000},
	[511] = {"BEAGLE", 45000},--самолет
	[512] = {"CROPDUST", 45000},--кукурузник
	[513] = {"STUNT", 45000},--спорт самолет
	[520] = {"HYDRA", 45000},
	[476] = {"RUSTLER", 45000},--самолет с пушками
	[460] = {"Skimmer", 30000},--самолет садится на воду
}

local car_cash_coef = 10
local car_cash_no = {456,428,420,574,416,408,437,453,593,407,448,563}
for k,v in pairs(cash_car) do
	local count = 0
	for _,v1 in pairs(car_cash_no) do
		if k ~= v1 then
			count = count+1
		end
	end

	if count == #car_cash_no then
		cash_car[k][2] = v[2]*car_cash_coef
	end
end
for k,v in pairs(cash_boats) do
	local count = 0
	for _,v1 in pairs(car_cash_no) do
		if k ~= v1 then
			count = count+1
		end
	end

	if count == #car_cash_no then
		cash_boats[k][2] = v[2]*car_cash_coef
	end
end
for k,v in pairs(cash_helicopters) do
	local count = 0
	for _,v1 in pairs(car_cash_no) do
		if k ~= v1 then
			count = count+1
		end
	end

	if count == #car_cash_no then
		cash_helicopters[k][2] = v[2]*car_cash_coef
	end
end
for k,v in pairs(cash_airplanes) do
	local count = 0
	for _,v1 in pairs(car_cash_no) do
		if k ~= v1 then
			count = count+1
		end
	end

	if count == #car_cash_no then
		cash_airplanes[k][2] = v[2]*car_cash_coef
	end
end

local interior_business = {
	{1, "Магазин оружия", 285.7870,-41.7190,1001.5160, 6},
	{5, "Магазин одежды", 225.3310,-8.6169,1002.1977, 45},
	{6, "Магазин 24/7", -26.7180,-55.9860,1003.5470, 50},--буду юзать это инт
	{0, "Заправка", 0,0,0, 56},
	{0, "Автомастерская", 0,0,0, 27},
}

local interior_house = {
	{5, "The Crack Den",	322.1117,	1119.3270,	1083.8830},--наркопритон
	{1, "Burglary House 1",	224.6351,	1289.012,	1082.141},
	{2, "Burglary House 2",	225.756,	1240.000,	1082.149},
	{2, "Burglary House 3",	447.470,	1398.348,	1084.305},
	{2, "Burglary House 4",	491.740,	1400.541,	1080.265},
	{3, "Burglary House 5",	234.733,	1190.391,	1080.258},
	{4, "Burglary House 6",	-262.91,	1454.966,	1084.367},
	{4, "Burglary House 7",	221.4296,	1142.423,	1082.609},
	{4, "Burglary House 8",	261.1168,	1286.519,	1080.258},
	{5, "Burglary House 9",	22.79996,	1404.642,	1084.43},
	{5, "Burglary House 10",	228.9003,	1114.477,	1080.992},
	{9, "Burglary House 12",	85.32596,	1323.585,	1083.859},
	{9, "Burglary House 13",	260.3189,	1239.663,	1084.258},
	{10, "Burglary House 14",	21.241,		1342.153,	1084.375},
	{6, "Burglary House 16",	-69.049,	1354.056,	1080.211},
	{15, "Burglary House 18",	327.808,	1479.74,	1084.438},
	{15, "Burglary House 19",	375.572,	1417.439,	1081.328},
	{15, "Burglary House 20",	384.644,	1471.479,	1080.195},
	{15, "Burglary House 21",	295.467,	1474.697,	1080.258},
	{8, "Burglary House 22",	-42.490,	1407.644,	1084.43},
	{6, "Safe House 3",	2333.0330,	-1073.9600,	1049.0230},
	{6, "Safe House 5",	2194.2910,	-1204.0150,	1049.0230},
	{6, "Safe House 6",	2308.8710,	-1210.7170,	1049.0230},
	{8, "Colonel Fuhrberger's House",	2807.8990,	-1172.9210,	1025.5700},--дом с пушкой
	{2, "Ryder's House",	2464.2110,	-1697.9520,	1013.5080},
	{3, "Johnson House",	2496.0500,	-1693.9260,	1014.7420},
	{6, "Burglary House 15",	234.319,	1066.455,	1084.208},--дорогой дом
	{5, "Burglary House 11",	140.5631,	1369.051,	1083.864},--дорогой дом
	{5, "Madd Dogg's Mansion",	1298.9116,	-795.9028,	1084.00},--огромный особняк
}

--здания для работ и фракций
local interior_job = {--12
	{1, "Мясокомбинат", 963.6078,2108.3970,1011.0300, 966.2333984375,2160.5166015625,10.8203125, 51, 1, "", 5},
	{6, "Лос Сантос ПД", 246.4510,65.5860,1003.6410, 1555.494140625,-1675.5419921875,16.1953125, 30, 2, ", Меню - X", 5},
	{10, "Сан Фиерро ПД", 246.4410,112.1640,1003.2190, -1605.7109375,710.28515625,13.8671875, 30, 3, ", Меню - X", 5},
	{3, "Лас Вентурас ПД", 238.384765625,140.4052734375,1003.0234375, 2287.1005859375,2432.3642578125,10.8203125, 30, 4, ", Меню - X", 5},
	{3, "Мэрия ЛС", 374.6708,173.8050,1008.3893, 1481.0576171875,-1772.3115234375,18.795755386353, 19, 5, ", Меню - X", 5},
	{2, "Завод продуктов", 2570.33,-1302.31,1044.12, -86.208984375,-299.36328125,2.7646157741547, 51, 6, "", 5},
	{3, "Мэрия СФ", 374.6708,173.8050,1008.3893, -2766.55078125,375.60546875,6.3346824645996, 19, 7, ", Меню - X", 5},
	{3, "Мэрия ЛВ", 374.6708,173.8050,1008.3893, 2447.6826171875,2376.3037109375,12.163512229919, 19, 8, ", Меню - X", 5},
	{4, "Гонки на мотоциклах", -1435.8690,-662.2505,1052.4650, -2109.66796875,-444.0263671875,38.734375, 33, 9, "", 5},
	{7, "Гонки на автомобилях", -1406.8232421875,-255.7607421875,1043.6507568359, 1097.6357421875,1597.7431640625,12.546875, 33, 10, "", 5},
	{15, "Дерби арена", -1394.20,987.62,1023.96, 2794.310546875,-1723.8642578125,11.84375, 33, 11, "", 5},
	{16, "Последний выживший", -1400,1250,1040, 2685.4638671875,-1802.6201171875,11.84375, 33, 12, "", 5},
	{10, "Казино 4 Дракона", 2009.4140,1017.8990,994.4680, 2019.3134765625,1007.6728515625,10.8203125, 43, 13, "", 5},
	{1, "Казино Калигула", 2235.2524,1708.5146,1010.6129, 2196.9619140625,1677.1708984375,12.3671875, 44, 14, ", Разгрузить товар - E", 5},
	{5, "Эль Кебрадос ПД", 322.72,306.43,999.15, -1389.66015625,2644.005859375,55.984375, 30, 15, ", Меню - X", 5},
	{5, "Форт Карсон ПД", 322.72,306.43,999.15, -217.837890625,979.171875,19.504064559937, 30, 16, ", Меню - X", 5},
	{5, "Диллимор ПД", 322.72,306.43,999.15, 626.9697265625,-571.796875,17.920680999756, 30, 17, ", Меню - X", 5},
	{5, "Эйнджел Пайн ПД", 322.72,306.43,999.15, -2161.2099609375,-2384.9052734375,30.893091201782, 30, 18, ", Меню - X", 5},
	{18, "Отель Атриум", 1726.1370,-1645.2300,20.2260, 1727.0732421875,-1637.03515625,20.217393875122, 35, 19, "", 5},
	{18, "Отель Сфинкс", 1726.1370,-1645.2300,20.2260, 2239.05078125,1285.7119140625,10.8203125, 35, 20, "", 5},
	{18, "Отель Виктория", 1726.1370,-1645.2300,20.2260, -2463.44140625,131.7275390625,35.171875, 35, 21, "", 5},
	{5, "Черный рынок", 322.1117,1119.3270,1083.8830, 2165.9541015625,-1671.1748046875,15.07315826416, 18, 22, ", Меню - X", 5},
	{3, "Зона 51", 374.6708,173.8050,1008.3893, 333.18359375,1951.68359375,17.640625, 20, 23, ", Меню - X", 5},
	{18, "Казарма", 1726.1370,-1645.2300,20.2260, 233.2578125,1840.21875,17.640625, 35, 24, "", 5},
	{6, "Тренажорный зал ЛС", 774.0870,-47.9830,1000.5860, 2229.9140625,-1721.26953125,13.561408996582, 54, 25, "", 5},
	{6, "Тренажорный зал СФ", 774.0870,-47.9830,1000.5860, -2270.642578125,-155.955078125,35.3203125, 54, 26, "", 5},
	{6, "Тренажорный зал ЛВ", 774.0870,-47.9830,1000.5860, 1968.7275390625,2295.87109375,16.455863952637, 54, 27, "", 5},
	{3, "Тотализатор", 826.8863,5.5091,1004.4830, 1288.7041015625,271.2421875,19.5546875, 37, 28, "", 5},
}

--пикапы для работ и фракций
local interior_job_pickup = {
	{createPickup ( 292.31268310547,1833.2623291016,18.05459022522, 3, get("job_icon"), 10000 ), {279.1279296875,1833.1435546875,18.08740234375}},--кпп1
	{createPickup ( 279.1279296875,1833.1435546875,18.08740234375, 3, get("job_icon"), 10000 ), {292.31268310547,1833.2623291016,18.05459022522}},--кпп2
	{createPickup ( 329.3095703125,1900.0595703125,17.640625, 3, get("job_icon"), 10000 ), {330.52850341797,1899.8177490234,41.026561737061}},--кр 1
	{createPickup ( 330.52850341797,1899.8177490234,41.026561737061, 3, get("job_icon"), 10000 ), {329.3095703125,1900.0595703125,17.640625}},--кр 2
}

local t_s_salon = {
	{2131.9775390625,-1151.322265625,24.062105178833, 55},--авто
	{1590.1689453125,1170.60546875,14.224066734314, 5},--верт
	{-2187.46875,2416.5576171875,5.1651339530945, 9},--лодки
}

--места поднятия предметов
local up_car_subject = {--{x,y,z, радиус 4, ид пнг 5, ид тс 6, зп 7}
	{89.9423828125,-304.623046875,1.578125, 15, 24, 456, 100},--склад продуктов
	{260.4326171875,1409.2626953125,10.506074905396, 15, 73, 456, 200},--нефтезавод
	{-1061.6103515625,-1195.5166015625,129.828125, 15, 88, 456, 200},--скотобойня
	{1461.939453125,974.8876953125,10.30264377594, 15, 89, 456, 50},--склад корма для коров
	{2492.3974609375,2773.46484375,10.803514480591, 15, 66, 428, 200},--kacc
	{2122.8994140625,-1790.56640625,13.5546875, 15, 31, 448, 200},--pizza
}

local up_player_subject = {--{x,y,z, радиус 4, ид пнг 5, зп 6, интерьер 7, мир 8, скин 9}
	{2559.1171875,-1287.2275390625,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{2551.1318359375,-1287.2294921875,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{2543.0859375,-1287.2216796875,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{2543.166015625,-1300.0927734375,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{2551.09375,-1300.09375,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{2559.0185546875,-1300.0927734375,1044.125, 2, 69, 1, 2, 6, 16},--завод продуктов
	{-491.4609375,-194.43359375,78.394332885742, 5, 67, 1, 0, 0, 27},--лесоповал
	{576.8212890625,846.5732421875,-42.264389038086, 5, 70, 1, 0, 0, 260},--рудник лв
	{1743.0302734375,-1864.4560546875,13.573830604553, 5, 74, 1, 0, 0, 253},--автобусник
	{964.064453125,2117.3544921875,1011.0302734375, 1, 30, 1, 1, 1, 0},--мясокомбинат
}

--места сброса предметов
local down_car_subject = {--{x,y,z, радиус 4, ид пнг 5, ид тс 6}
	{2787.8974609375,-2455.974609375,13.633636474609, 15, 24, 456},--порт лс
	{2787.8974609375,-2455.974609375,13.633636474609, 15, 73, 456},--порт лс
	{966.951171875,2132.8623046875,10.8203125, 15, 88, 456},--мясокомбинат
	{-1079.947265625,-1195.580078125,129.79998779297, 15, 89, 456},--скотобойня корм
}

--места разгрузки
local down_car_subject_pos = {--{x,y,z, радиус 4, ид пнг 5, ид тс 6, зп 7}
	{-1813.2890625,-1654.3330078125,22.398532867432, 15, 75, 408, 200},--свалка
	{2315.595703125,6.263671875,26.484375, 15, 65, 428, 200},--банк
	{2463.7587890625,-2716.375,1.1451852619648, 15, 78, 453, 200},--доки лс
}

local down_player_subject = {--{x,y,z, радиус 4, ид пнг 5, интерьер 6, мир 7}
	{942.4775390625,2117.900390625,1011.0302734375, 5, 48, 1, 1},--мясокомбинат
	{2564.779296875,-1293.0673828125,1044.125, 2, 62, 2, 6},--завод продуктов
	{681.7744140625,823.8447265625,-26.840600967407, 5, 71, 0, 0},--рудник лв
	{-488.2119140625,-176.8603515625,78.2109375, 5, 68, 0, 0},--склад бревен
	{-1633.845703125,-2239.08984375,31.4765625, 5, 28, 0, 0},--охотничий дом
	{681.7744140625,823.8447265625,-26.840600967407, 5, 16, 0, 0},--рудник лв
	{2435.361328125,-2705.46484375,3, 5, 32, 0, 0},--доки лc
	{2564.779296875,-1293.0673828125,1044.125, 2, 110, 2, 6},--завод продуктов
}

local anim_player_subject = {--{x,y,z, радиус 4, ид пнг1 5, ид пнг2 6, зп 7, анимация1 8, анимация2 9, интерьер 10, мир 11, время работы анимации 12} также нужно прописать ид пнг 
	--завод продуктов
	{2558.6474609375,-1291.0029296875,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2556.080078125,-1290.9970703125,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2553.841796875,-1291.0048828125,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2544.4326171875,-1291.00390625,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2541.9169921875,-1290.9951171875,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2541.9091796875,-1295.8505859375,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2544.427734375,-1295.8505859375,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2553.7578125,-1295.8505859375,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2556.2578125,-1295.8544921875,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},
	{2558.5478515625,-1295.8505859375,1044.125, 1, 69, 62, 1, "int_house", "wash_up", 2, 6, 5},

	--лесоповал
	{-511.3896484375,-193.8212890625,78.391899108887, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-515.8330078125,-194.17578125,78.40625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-521.138671875,-194.4169921875,78.40625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-525.8740234375,-194.6396484375,78.40625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-530.169921875,-194.83984375,78.40625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-535.298828125,-195.0869140625,78.40625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-547.07421875,-158.0869140625,77.827285766602, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-542.3623046875,-157.970703125,77.814529418945, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-536.755859375,-158.0146484375,77.819396972656, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-531.126953125,-157.77734375,77.626838684082, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-525.6103515625,-157.7939453125,77.082763671875, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-494.0009765625,-154.6943359375,76.312866210938, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-487.8037109375,-154.35546875,76.055053710938, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-482.490234375,-154.0693359375,75.835266113281, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-477.3134765625,-153.7890625,75.568603515625, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},
	{-471.2958984375,-153.5048828125,75.246078491211, 1, 67, 68, 1, "chainsaw", "weapon_csaw", 0, 0, 5},

	--рудник лв
	{630.7001953125,865.71032714844,-42.660102844238, 1, 70, 16, 1, "baseball", "bat_4", 0, 0, 5},
	{619.72265625,873.4443359375,-42.9609375, 1, 70, 16, 1, "baseball", "bat_4", 0, 0, 5},
	{607.9052734375,864.9892578125,-42.809223175049, 1, 70, 16, 1, "baseball", "bat_4", 0, 0, 5},
	{610.1083984375,845.86267089844,-42.524024963379, 1, 70, 16, 1, "baseball", "bat_4", 0, 0, 5},
	{627.5458984375,844.70349121094,-42.33695602417, 1, 70, 16, 1, "baseball", "bat_4", 0, 0, 5},
	{579.53356933594,874.83459472656,-43.100883483887, 1, 70, 71, 1, "baseball", "bat_4", 0, 0, 5},
	{574.99548339844,889.15100097656,-42.958339691162, 1, 70, 71, 1, "baseball", "bat_4", 0, 0, 5},
	{559.23962402344,892.81115722656,-42.695762634277, 1, 70, 71, 1, "baseball", "bat_4", 0, 0, 5},
	{552.41442871094,878.68420410156,-42.364948272705, 1, 70, 71, 1, "baseball", "bat_4", 0, 0, 5},
	{563.02087402344,863.94885253906,-42.350147247314, 1, 70, 71, 1, "baseball", "bat_4", 0, 0, 5},
}

for k=1,10 do
	anim_player_subject[k][7] = 100
	anim_player_subject[k][12] = 10
end

for k=11,26 do
	anim_player_subject[k][7] = 100
	anim_player_subject[k][12] = 10
end

for k=27,36 do
	anim_player_subject[k][7] = 100
	anim_player_subject[k][12] = 10
end

--камеры полиции
local prison_cell = {
	{interior_job[2][1], interior_job[2][10], "кпз_лс",		263.84765625,	77.6044921875,	1001.03906},
	{interior_job[3][1], interior_job[3][10], "кпз_сф1",	227.5947265625,	110.0537109375,	999.015625},
	{interior_job[3][1], interior_job[3][10], "кпз_сф2",	223.373046875,	110.0986328125,	999.015625},
	{interior_job[3][1], interior_job[3][10], "кпз_сф3",	219.337890625,	110.4619140625,	999.015625},
	{interior_job[3][1], interior_job[3][10], "кпз_сф4",	215.59375,		109.8916015625,	999.015625},
	{interior_job[4][1], interior_job[4][10], "кпз_лв",		198.283203125,	162.1220703125,	1003.02996},
	{interior_job[4][1], interior_job[4][10], "кпз_лв2",	198.0390625,	174.78125,		1003.02343},
	{interior_job[4][1], interior_job[4][10], "кпз_лв3",	193.6708984375,	176.7255859375,	1003.02343},
}

--места спавна у госпиталя
local hospital_spawn = {
	{1607.423828125,1815.244140625,10.8203125},
	{-2654.4873046875,640.1650390625,14.454549789429},
	{1172.0771484375,-1323.28125,15.402851104736},
	{2027.0,-1412.3037109375,16.9921875},
	{-320.17578125,1048.234375,20.340259552002},
	{-1514.671875,2518.9306640625,56.0703125},
	{-2204.0732421875,-2309.5732421875,31.375},
	{1241.33984375,325.9052734375,19.7555103302},
}

local station = {
	{1743.119140625,-1943.5732421875,13.569796562195, 10, "вокзал лс"},
	{-1973.22265625,116.78515625,27.6875, 10, "вокзал сф"},
	{2848.4521484375,1291.462890625,11.390625, 10, "вокзал лв"},
}

--инв-рь игрока
local array_player_1 = {}
local array_player_2 = {}

local state_inv_player = {}--состояние инв-ря игрока 0-выкл, 1-вкл
local state_gui_window = {}--состояние гуи окна 0-выкл, 1-вкл
local logged = {}--0-не вошел, 1-вошел
local enter_house = {}--0-не вошел, 1-вошел (не удалять)
local enter_business = {}--0-не вошел, 1-вошел (не удалять)
local enter_job = {}--0-не вошел, 1-вошел (не удалять)
local speed_car_device = {}--отображение скорости авто, 0-выкл, 1-вкл
local arrest = {}--арест игрока, 0-нет, 1-да, 2-да админом
local crimes = {}--преступления
local robbery_player = {}--ограбление, 0-нет, 1-да
local robbery_timer = {}--таймер ограбления
local gps_device = {}--отображение координат игрока, 0-выкл, 1-вкл
local job = {}--переменная работ
local armour = {}--броня
local game = {}--карты игрока
local accept_player = {}--переменная игры
local drone = {}--дрон

--нужды
local alcohol = {}
local satiety = {}
local hygiene = {}
local sleep = {}
local drugs = {}
local max_alcohol = 500
local max_satiety = 100
local max_hygiene = 100
local max_sleep = 100
local max_drugs = 100

--инв-рь авто
local array_car_1 = {
	["0"] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local array_car_2 = {
	["0"] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}
local fuel = {--топливный бак
	["0"] = 50,
}
local kilometrage = {--пробег
	["0"] = 0,
}

--инв-рь дома
local array_house_1 = {}
local array_house_2 = {}

--инв-рь ящика
local array_box_1 = {}
local array_box_2 = {}

-------------------пользовательские функции 2----------------------------------------------
function debuginfo ()
	if(point_guns_zone[1] == 1) then
	
		time_guns_zone = time_guns_zone-1

		if(time_guns_zone == 0) then
		
			time_guns_zone = time_gz

			if(point_guns_zone[4] > point_guns_zone[6]) then
			
				guns_zone[point_guns_zone[2]][2] = point_guns_zone[3]

				local r,g,b = getTeamColor ( name_mafia[point_guns_zone[3]][1] )

				setRadarAreaColor ( guns_zone[point_guns_zone[2]][1], r, g, b, 100 )

				sendMessage(root, "[НОВОСТИ] "..getTeamName (name_mafia[point_guns_zone[3]][1]).." захватила территорию", color_mes.green)

				sqlite( "UPDATE guns_zone SET mafia = '"..point_guns_zone[3].."' WHERE number = '"..point_guns_zone[2].."'")
			
			else
			
				guns_zone[point_guns_zone[2]][2] = point_guns_zone[5]

				local r,g,b = getTeamColor ( name_mafia[point_guns_zone[3]][1] )

				setRadarAreaColor ( guns_zone[point_guns_zone[2]][1], r, g, b, 100 )

				sendMessage(root, "[НОВОСТИ] "..getTeamName (name_mafia[point_guns_zone[5]][1]).." удержала территорию", color_mes.green)
			end

			setRadarAreaFlashing ( guns_zone[point_guns_zone[2]][1], false )

			point_guns_zone[1] = 0
			point_guns_zone[2] = 0--gz

			point_guns_zone[3] = 0--mafia A
			point_guns_zone[4] = 0--points

			point_guns_zone[5] = 0--mafia D
			point_guns_zone[6] = 0--points
		end
	end

	for k,localPlayer in pairs(getElementsByType("player")) do
		local playername = getPlayerName(localPlayer)
		local hour, minute = getTime()

		if(point_guns_zone[1] == 1) then
			points_add_in_gz(localPlayer, 1)
		end

		setElementData(localPlayer, "crimes_data", crimes[playername])
		setElementData(localPlayer, "alcohol_data", alcohol[playername])
		setElementData(localPlayer, "satiety_data", satiety[playername])
		setElementData(localPlayer, "hygiene_data", hygiene[playername])
		setElementData(localPlayer, "sleep_data", sleep[playername])
		setElementData(localPlayer, "drugs_data", drugs[playername])
		setElementData(localPlayer, "speed_car_device_data", speed_car_device[playername])
		setElementData(localPlayer, "gps_device_data", gps_device[playername])
		setElementData(localPlayer, "timeserver", hour..":"..minute)

		local vehicleid = getPlayerVehicle(localPlayer)
		if (vehicleid) then
			local plate = getVehiclePlateText(vehicleid)
			setElementData(localPlayer, "fuel_data", fuel[plate])
			setElementData(localPlayer, "kilometrage_data", kilometrage[plate])
		end

		if search_inv_player_2_parameter(localPlayer, 85) ~= 0 then
			setElementData(localPlayer, "guns_zone2", {point_guns_zone, time_guns_zone})
		else
			setElementData(localPlayer, "guns_zone2", false)
		end

		if armour[playername] ~= 0 and getPedArmor(localPlayer) == 0 then
			destroyElement(armour[playername])
			armour[playername] = 0
		end

		if crimes[playername] ~= 0 and search_inv_player_2_parameter(localPlayer, 10) ~= 0 then
			if inv_player_delet(localPlayer, 10, search_inv_player_2_parameter(localPlayer, 10), true) then
				sendMessage(localPlayer, "Вы больше не полицейский", color_mes.yellow)

				if job[playername] == 18 or job[playername] == 13 then
					job_0( playername )
				end
			end
		end
	end
end

function need_1 ()
	for k,localPlayer in pairs(getElementsByType("player")) do
		local playername = getPlayerName(localPlayer)

		if logged[playername] == 1 then
			local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )

			--нужды
			if hygiene[playername] == 0 and getElementModel(localPlayer) ~= 230 then
				setElementModel(localPlayer, 230)
			elseif hygiene[playername] > 0 and getElementModel(localPlayer) ~= result[1]["skin"] then
				setElementModel(localPlayer, result[1]["skin"])
			end
		end
	end
end

function need()--нужды
	for k,localPlayer in pairs(getElementsByType("player")) do
		local playername = getPlayerName(localPlayer)

		if logged[playername] == 1 then
			if alcohol[playername] == 500 then
				local hygiene_minys = 25

				setElementHealth( localPlayer, getElementHealth(localPlayer)-100 )

				sendMessage(localPlayer, "-100 хп", color_mes.yellow)

				if hygiene[playername]-hygiene_minys >= 0 then
					hygiene[playername] = hygiene[playername]-hygiene_minys
					sendMessage(localPlayer, "-"..hygiene_minys.." ед. чистоплотности", color_mes.yellow)
				end

				me_chat(localPlayer, playername.." стошнило")

				setPedAnimation(localPlayer, "food", "eat_vomit_p", -1, false, false, false, false)
			end


			if drugs[playername] == 100 then
				setElementHealth( localPlayer, getElementHealth(localPlayer)-200 )
				sendMessage(localPlayer, "-200 хп", color_mes.yellow)
			end


			if alcohol[playername] ~= 0 then
				alcohol[playername] = alcohol[playername]-10
			end


			if drugs[playername]-0.1 >= 0 then
				drugs[playername] = drugs[playername]-0.1
			else
				drugs[playername] = 0
			end


			if satiety[playername] == 0 then
				setElementHealth( localPlayer, getElementHealth(localPlayer)-1 )
			else
				satiety[playername] = satiety[playername]-1
			end


			if hygiene[playername] == 0 then

			else
				hygiene[playername] = hygiene[playername]-1
			end


			if sleep[playername] == 0 then
				setElementHealth( localPlayer, getElementHealth(localPlayer)-1 )
			else
				sleep[playername] = sleep[playername]-1
			end
		end
	end
end

function fuel_down()--система топлива авто
	for k,vehicleid in pairs(getElementsByType("vehicle")) do
		local plate = getVehiclePlateText(vehicleid)
		local engine = getVehicleEngineState ( vehicleid )
		local fuel_down_number = 0.0002

		if engine and plate ~= "0" then
			if fuel[plate] <= 0 then
				setVehicleEngineState ( vehicleid, false )
			else
				if getSpeed(vehicleid) == 0 then
					fuel[plate] = fuel[plate] - fuel_down_number
				else
					fuel[plate] = fuel[plate] - (fuel_down_number*getSpeed(vehicleid))
					kilometrage[plate] = kilometrage[plate] + (getSpeed(vehicleid)/3600)
				end
			end
		end
	end
end

function timer_earth_clear()--очистка земли
	local hour, minute = getTime()

	if hour == 0 and get("earth_true") then
		local count_earth = 0

		for i,v in pairs(earth) do
			count_earth = count_earth+1
		end

		print("[timer_earth_clear] max_earth "..max_earth..", count_earth "..count_earth)

		earth = {}
		max_earth = 0

		setElementData(resourceRoot, "earth_data", earth)

		for k,localPlayer in pairs(getElementsByType("player")) do
			sendMessage(localPlayer, "[НОВОСТИ] Улицы очищенны от мусора", color_mes.green)
		end
	end
end

function prison_timer()--античит если не в тюрьме
	for i,localPlayer in pairs(getElementsByType("player")) do
		local count = 0
		local playername = getPlayerName(localPlayer)
		local x,y,z = getElementPosition(localPlayer)

		if arrest[playername] ~= 0 then
			for k,v in pairs(prison_cell) do
				if not isPointInCircle3D(x,y,z, v[4],v[5],v[6], 5) then
					count = count+1
				end
			end

			if count == #prison_cell then
				local randomize = random(1,#prison_cell)

				if getPlayerVehicle(localPlayer) then
					removePedFromVehicle(localPlayer)
				end

				triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
				state_inv_player[playername] = 0

				triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )
				state_gui_window[playername] = 0

				enter_house[playername] = {0,0}
				enter_business[playername] = 0
				enter_job[playername] = 0

				takeAllWeapons ( localPlayer )
				job_0(playername)
				car_theft_fun(playername)
				robbery_kill( playername )

				setElementDimension(localPlayer, prison_cell[randomize][2])
				setElementInterior(localPlayer, 0)
				setElementInterior(localPlayer, prison_cell[randomize][1], prison_cell[randomize][4], prison_cell[randomize][5], prison_cell[randomize][6])
			end
		end
	end
end

function prison()--таймер заключения
	for i,localPlayer in pairs(getElementsByType("player")) do
		local playername = getPlayerName(localPlayer)

		if arrest[playername] == 1 then
			if crimes[playername] == 1 then
				arrest[playername] = 0
				crimes[playername] = 0

				local randomize = random(2,4)

				setElementDimension(localPlayer, 0)
				setElementInterior(localPlayer, 0, interior_job[randomize][6], interior_job[randomize][7], interior_job[randomize][8])

				sendMessage(localPlayer, "Вы свободны, больше не нарушайте", color_mes.yellow)

			elseif crimes[playername] > 1 then
				crimes[playername] = crimes[playername]-1

				sendMessage(localPlayer, "Вам сидеть ещё "..(crimes[playername]).." мин", color_mes.yellow)
			end

		elseif arrest[playername] == 2 then
			if array_player_2[playername][25] == 1 then
				arrest[playername] = 0

				local randomize = random(2,4)

				setElementDimension(localPlayer, 0)
				setElementInterior(localPlayer, 0, interior_job[randomize][6], interior_job[randomize][7], interior_job[randomize][8])

				sendMessage(localPlayer, "Вы свободны, больше не нарушайте", color_mes.yellow)

				inv_server_load(localPlayer, "player", 24, 0, 0, playername)

			elseif array_player_2[playername][25] > 1 then
				array_player_2[playername][25] = array_player_2[playername][25]-1

				sendMessage(localPlayer, "Вам сидеть ещё "..array_player_2[playername][25].." мин", color_mes.yellow)

				inv_server_load(localPlayer, "player", 24, 92, array_player_2[playername][25], playername)
			end
		end
	end
end

function pay_taxation()
	local time = getRealTime()

	if time["hour"] == 12 and time["minute"] == 0 then
		local result = sqlite( "SELECT * FROM car_db" )
		for k,v in pairs(result) do
			if v["taxation"] > 0 then
				sqlite( "UPDATE car_db SET taxation = taxation - '1' WHERE number = '"..v["number"].."'")
			end
		end

		local result = sqlite( "SELECT * FROM house_db" )
		for k,v in pairs(result) do
			if v["taxation"] > 0 then
				sqlite( "UPDATE house_db SET taxation = taxation - '1' WHERE number = '"..v["number"].."'")
			end
		end

		local result = sqlite( "SELECT * FROM business_db" )
		for k,v in pairs(result) do
			if v["taxation"] > 0 then
				sqlite( "UPDATE business_db SET taxation = taxation - '1' WHERE number = '"..v["number"].."'")
			end
		end

		local result = sqlite( "SELECT * FROM cow_farms_db" )
		for k,v in pairs(result) do
			if v["taxation"] > 0 then
				sqlite( "UPDATE cow_farms_db SET taxation = taxation - '1' WHERE number = '"..v["number"].."'")
			end
		end

		print("[pay_taxation]")
	end

	if time["minute"] == 0 then
		pay_money_gz()

		print("[pay_money_gz]")
	end

	if time["hour"] == 23 and time["minute"] == 50 then
		for i=1,10 do
			sendMessage(root, "РЕСТАРТ СЕРВЕРА ЧЕРЕЗ 10 МИНУТ", color_mes.red)
		end
	end

	if time["hour"] == 0 and time["minute"] == 0 then
		--restartAllResources()
	end

	for k,v in pairs(harvest) do
		if v[2] > 0 then
			harvest[k][2] = v[2]-1

		elseif v[3] == 0 then
			destroyElement(v[6])
			destroyElement(v[7])

			harvest[k] = nil

		elseif v[2] == 0 then
			harvest[k][3] = v[3]-1
		end
	end

	setElementData(resourceRoot, "harvest", harvest)
end

function pay_money_gz()
	for k1,v1 in pairs(name_mafia) do
		if k1 ~= 0 then
			local count = 0
			local count2 = 0
			local count_mafia = select_sqlite_t(85, k1)

			if count_mafia then
				for k,v in pairs(guns_zone) do
					if(v[2] == k1) then
						count = count+1

						for k1,v1 in pairs(sqlite( "SELECT * FROM business_db" )) do	
							if(isInsideRadarArea(v[1], v1["x"],v1["y"])) then
								count2 = count2+1
							end
						end
					end
				end

				local money_gz = tonumber(split(get("money_guns_zone")*count/#count_mafia, ".")[1])
				local money_gzb = tonumber(split(get("money_guns_zone_business")*count2/#count_mafia, ".")[1])

				for k,v in pairs(count_mafia) do
					local localPlayer = getPlayerFromName(v)
					local playername = v

					if localPlayer and logged[playername] == 1 then
						sendMessage(localPlayer, "Вы получили "..money_gz.."$ за удержание территорий", color_mes.green)
						inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money_gz, playername )

						sendMessage(localPlayer, "Вы получили "..money_gzb.."$ за крышивание бизнесов", color_mes.green)
						inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money_gzb, playername )
					end
				end
			end
		end
	end
end

function onChat(message, messageType)
	local localPlayer = source
	local playername = getPlayerName(localPlayer)

	cancelEvent()

	if logged[playername] == 0 or arrest[playername] ~= 0 then
		return
	end

	if messageType ~= 1 then
		local count = 0
		local say = "(Всем OOC) "..getPlayerName( localPlayer ).." ["..getElementData(localPlayer, "player_id").."]: " .. message
		local say_10_r = "(Ближний IC) "..getPlayerName( localPlayer ).." ["..getElementData(localPlayer, "player_id").."]: " .. message

		for k,player in pairs(getElementsByType("player")) do
			local x,y,z = getElementPosition(localPlayer)
			local x1,y1,z1 = getElementPosition(player)
			local player_name = getPlayerName(player)

			if(logged[player_name] == 1 and isPointInCircle3D(x,y,z, x1,y1,z1, get("me_radius") ) and player ~= localPlayer) then
			
				count = count + 1
			end
		end
		
		if (count == 0) then
			sendMessage( root, say, color_mes.gray )
		else 
			ic_chat( localPlayer, say_10_r )
		end

	else 
		me_chat_player(localPlayer, playername.." "..message)
	end
end
addEventHandler("onPlayerChat", root, onChat)

addEventHandler("onPlayerCommand",root,
function(command)
	local localPlayer = source
	local playername = getPlayerName(localPlayer)

	if command == "msg" then
		cancelEvent()
	end
end)

function load_inv(val, value, text)
	if value == "player" then
		for k,v in pairs(split(text, ",")) do
			local spl = split(v, ":")
			array_player_1[val][k] = tonumber(spl[1])
			array_player_2[val][k] = tonumber(spl[2])
		end
	elseif value == "car" then
		for k,v in pairs(split(text, ",")) do
			local spl = split(v, ":")
			array_car_1[val][k] = tonumber(spl[1])
			array_car_2[val][k] = tonumber(spl[2])
		end
	elseif value == "house" then
		for k,v in pairs(split(text, ",")) do
			local spl = split(v, ":")
			array_house_1[val][k] = tonumber(spl[1])
			array_house_2[val][k] = tonumber(spl[2])
		end
	elseif value == "box" then
		for k,v in pairs(split(text, ",")) do
			local spl = split(v, ":")
			array_box_1[val][k] = tonumber(spl[1])
			array_box_2[val][k] = tonumber(spl[2])
		end
	end
end

function save_inv(val, value)
	if value == "player" then
		local text = ""
		for i=0,get("max_inv")+max_inv_additional do
			text = text..array_player_1[val][i+1]..":"..array_player_2[val][i+1]..","
		end
		return text
	elseif value == "car" then
		local text = ""
		for i=0,get("max_inv") do
			text = text..array_car_1[val][i+1]..":"..array_car_2[val][i+1]..","
		end
		return text
	elseif value == "house" then
		local text = ""
		for i=0,get("max_inv") do
			text = text..array_house_1[val][i+1]..":"..array_house_2[val][i+1]..","
		end
		return text
	elseif value == "box" then
		local text = ""
		for i=0,get("max_inv") do
			text = text..array_box_1[val][i+1]..":"..array_box_2[val][i+1]..","
		end
		return text
	end
end

---------------------------------------игрок------------------------------------------------------------
function search_inv_player( localPlayer, id1, id2 )--цикл по поиску предмета в инв-ре игрока
	local playername = getPlayerName ( localPlayer )
	local val = 0

	for i=0,get("max_inv") do
		if array_player_1[playername][i+1] == id1 and array_player_2[playername][i+1] == id2 then
			val = val + 1
		end
	end

	return val
end

function search_inv_player_police( localPlayer, id )--цикл по выводу предметов
	local playername = getPlayerName ( localPlayer )

	for i=1,get("max_inv") do
		if array_player_1[id][i+1] ~= 0 then
			do_chat(localPlayer, info_png[ array_player_1[id][i+1] ][1].." "..array_player_2[id][i+1].." "..info_png[ array_player_1[id][i+1] ][2].." - "..playername)
		end
	end
end

function search_inv_player_2_parameter(localPlayer, id1)--вывод 2 параметра предмета в инв-ре игрока
	local playername = getPlayerName ( localPlayer )

	for i=0,get("max_inv") do
		if array_player_1[playername][i+1] == id1 then
			return array_player_2[playername][i+1]
		end
	end

	return 0
end

function amount_inv_player_1_parameter(localPlayer, id1)--выводит коли-во предметов
	local playername = getPlayerName ( localPlayer )
	local val = 0

	for i=0,get("max_inv") do
		if (array_player_1[playername][i+1] == id1) then
		
			val = val + 1
		end
	end

	return val
end

function amount_inv_player_2_parameter(localPlayer, id1)--выводит сумму всех 2-ых параметров предмета
	local playername = getPlayerName ( localPlayer )
	local val = 0

	for i=0,get("max_inv") do
		if (array_player_1[playername][i+1] == id1) then
		
			val = val + array_player_2[playername][i+1]
		end
	end

	return val
end

function inv_player_empty(localPlayer, id1, id2)--выдача предмета игроку
	local playername = getPlayerName ( localPlayer )

	for i=0,get("max_inv") do
		if array_player_1[playername][i+1] == 0 then
			inv_server_load( localPlayer, "player", i, id1, id2, playername )

			return true
		end
	end

	return false
end

function inv_player_delet(localPlayer, id1, id2, delet_inv, quest_bool)--удаления предмета игрока
	local playername = getPlayerName ( localPlayer )

	if delet_inv then
		triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
		state_inv_player[playername] = 0
	end

	for i=0,get("max_inv") do
		if array_player_1[playername][i+1] == id1 and array_player_2[playername][i+1] == id2 then
			inv_server_load( localPlayer, "player", i, 0, 0, playername )

			if quest_bool then
				quest_player(localPlayer, id1)
			end

			return true
		end
	end

	return false
end

function robbery(localPlayer, zakon, money, x1,y1,z1, radius, text)
	local playername = getPlayerName ( localPlayer )

	if isElement ( localPlayer ) then
		if robbery_player[playername] == 1 then
			local x,y,z = getElementPosition(localPlayer)
			local cash = random(money/2,money)

			if isPointInCircle3D(x1,y1,z1, x,y,z, radius) then
				addcrimes(localPlayer, zakon)

				sendMessage(localPlayer, "Вы унесли "..cash.."$", color_mes.green )

				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+cash, playername )
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы покинули место ограбления", color_mes.red)
			end

			robbery_kill( playername )
		end
	end
end

function robbery_kill( playername )
	if robbery_player[playername] == 1 then
		robbery_player[playername] = 0

		if isTimer(robbery_timer[playername]) then
			killTimer(robbery_timer[playername])
		end

		robbery_timer[playername] = 0
	end
end

function select_sqlite(id1, id2)--выводит имя владельца любого предмета
	for k,result in pairs(sqlite( "SELECT * FROM account" )) do
		for k,v in pairs(split(result["inventory"], ",")) do
			local spl = split(v, ":")
			if tonumber(spl[1]) == id1 and tonumber(spl[2]) == id2 then
				return result["name"]
			end
		end
	end

	return false
end

function select_sqlite_t(id1, id2)--выводит таблицу имен владельцев любого предмета
	local table_name = {}

	for k,result in pairs(sqlite( "SELECT * FROM account" )) do
		for k,v in pairs(split(result["inventory"], ",")) do
			local spl = split(v, ":")
			if tonumber(spl[1]) == id1 and tonumber(spl[2]) == id2 then
				table.insert(table_name, result["name"])
			end
		end
	end

	if #table_name ~= 0 then
		return table_name
	else
		return false
	end
end

function player_hotel (localPlayer, id)
	local playername = getPlayerName(localPlayer)

	if ((get("price_hotel")) <= search_inv_player_2_parameter(localPlayer, 1)) then

		local sleep_hygiene_plus = 100

		if (id == 55) then

			hygiene[playername] = sleep_hygiene_plus
			sendMessage(localPlayer, "+"..sleep_hygiene_plus.." ед. чистоплотности", color_mes.yellow)
			me_chat(localPlayer, playername.." помылся(ась)")

		elseif (id == 56) then

			sleep[playername] = sleep_hygiene_plus
			sendMessage(localPlayer, "+"..sleep_hygiene_plus.." ед. сна", color_mes.yellow)
			me_chat(localPlayer, playername.." вздремнул(а)")
		end

		sendMessage(localPlayer, "Вы заплатили "..(get("price_hotel")).."$", color_mes.orange )

		inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(get("price_hotel")), localPlayer )
					
		return true

	else 

		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return false
	end
end

function random_sub (localPlayer, id)--выпадение предметов

	local random_sub_array = {
		{69, { {82,1,20} }},
		{48, { {90,3,20} }},
	}

	local playername = getPlayerName ( localPlayer )
	local randomize1 = -1
	local randomize2 = random(1,100)
	for k,v in pairs(random_sub_array) do
		if (id == v[1]) then
		
			randomize1 = random(1,#v[2])
			if (randomize2 <= v[2][randomize1][3]) then
			
				local id1 = v[2][randomize1][1]
				local id2 = v[2][randomize1][2]
				if (inv_player_empty(localPlayer, id1, id2)) then
				
					sendMessage(localPlayer, "Вы получили "..info_png[id1][1].." "..id2.." "..info_png[id1][2], color_mes.svetlo_zolotoy)
				end
			end
			break
		end
	end
end

function getPlayerId( id )--узнать имя игрока из ид
	for k,player in pairs(getElementsByType("player")) do
		if getElementData(player, "player_id") == tonumber(id) then
			return getPlayerName(player), player
		end
	end

	return false
end

function points_add_in_gz(localPlayer, value) 

	local x,y,z = getElementPosition(localPlayer)

	for k,v in pairs(guns_zone) do
		if(isInsideRadarArea (v[1], x,y) and k == point_guns_zone[2]) then
		
			if (search_inv_player_2_parameter(localPlayer, 85) ~= 0 and search_inv_player_2_parameter(localPlayer, 85) == point_guns_zone[3]) then
			
				point_guns_zone[4] = point_guns_zone[4]+1*value
			
			elseif(search_inv_player_2_parameter(localPlayer, 85) ~= 0 and search_inv_player_2_parameter(localPlayer, 85) == point_guns_zone[5]) then
			
				point_guns_zone[6] = point_guns_zone[6]+1*value
			end
		end
	end
end

function setPlayerNametagColor_fun( localPlayer )
	if (search_inv_player_2_parameter(localPlayer, 44) ~= 0) then
		setPlayerNametagColor(localPlayer, color_mes.lyme[1],color_mes.lyme[2],color_mes.lyme[3])

	elseif (search_inv_player(localPlayer, 45, 1) ~= 0) then
		setPlayerNametagColor(localPlayer, color_mes.green[1],color_mes.green[2],color_mes.green[3])

	elseif (search_inv_player_2_parameter(localPlayer, 10) ~= 0) then
		local r,g,b = getTeamColor ( fraction_table[1][1] )
		setPlayerNametagColor(localPlayer, r,g,b)
		setPlayerTeam ( localPlayer, fraction_table[1][1] )

	elseif (search_inv_player_2_parameter(localPlayer, 85) ~= 0) then
		local r,g,b = getTeamColor ( name_mafia[search_inv_player_2_parameter(localPlayer, 85)][1] )
		setPlayerNametagColor(localPlayer, r,g,b)
		setPlayerTeam ( localPlayer, name_mafia[search_inv_player_2_parameter(localPlayer, 85)][1] )

	else 
		setPlayerNametagColor(localPlayer, color_mes.white[1],color_mes.white[2],color_mes.white[3])
		setPlayerTeam ( localPlayer, nil )
	end

	setElementData(localPlayer, "admin_data", search_inv_player_2_parameter(localPlayer, 44))
end

function quest_player(localPlayer, id)
	local playername = getPlayerName(localPlayer)

	if getElementData(localPlayer, "quest_select") ~= "0:0" then
		local spl = split(getElementData(localPlayer, "quest_select"), ":")
		local quest = tonumber(spl[1])
		local quest_progress = tonumber(spl[2])

		if 1 <= quest and quest <= 3 then
			if id == quest_table[quest][5] then
				quest_progress = quest_progress+1
				setElementData(localPlayer, "quest_select", quest..":"..quest_progress)
			end
			
			if quest_table[quest][3] <= quest_progress then
				if quest_table[quest][7][1] ~= 0 then
					if not inv_player_empty(localPlayer, quest_table[quest][7][1], quest_table[quest][7][2]) then
						sendMessage(localPlayer, "[ОШИБКА] Для завершения квеста освободите инвентарь", color_mes.red)
						return
					else
						sendMessage(localPlayer, "[QUEST] Вы получили "..info_png[quest_table[quest][7][1]][1].." "..quest_table[quest][7][2].." "..info_png[quest_table[quest][7][1]][2], color_mes.svetlo_zolotoy)
					end
				end

				setElementData(localPlayer, "quest_select", "0:0")

				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+quest_table[quest][6], playername )

				sendMessage(localPlayer, "[QUEST] Вы получили "..quest_table[quest][6].."$", color_mes.green)

				table.insert(quest_table[quest][8], playername)

				sqlite_load(localPlayer, "quest_table")
			end
		end
	end
end

function addcrimes(localPlayer, value)
	local crimes_plus = value
	local playername = getPlayerName(localPlayer)
	crimes[playername] = crimes[playername]+crimes_plus
	sendMessage(localPlayer, "+"..crimes_plus.." преступление, всего преступлений "..crimes[playername], color_mes.blue)
end

function rental_car(localPlayer, job)
	local playername = getPlayerName(localPlayer)
	local val1,val2 = 6,random_car_number(99999999-getMaxPlayers(),99999999)
	local car = {--ид тс 1, цена аренды 2
		[1] = {420, 1000},
		[2] = {408, 1000},
		[3] = {428, 1000},
		[4] = {453, 1000},
		[5] = {593, 1000},
		[7] = {456, 1000},
		[8] = {428, 1000},
		[9] = {437, 1000},
		[10] = {416, 1000},
		[11] = {574, 1000},
		[12] = {407, 1000},
		[13] = {601, 1000},
		[16] = {448, 1000},
		[18] = {599, 1000},
		[19] = {563, 1000},
	}

	if car[job] then
		if car[job][2] > search_inv_player_2_parameter(localPlayer, 1) then
			sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
			return
		end

		if inv_player_empty(localPlayer, val1, val2) then
		else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
			return
		end

		setElementData(localPlayer, "car_rental", val2)

		sendMessage(localPlayer, "Вы заплатили за аренду т/с "..car[job][2].."$", color_mes.yellow)

		inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-car[job][2], playername )

		local x,y,z = getElementPosition(localPlayer)
		local rot = 0
		local color = {255,255,255}
		local car_rgb_text = color[1]..","..color[2]..","..color[3]

		local color = {255,255,255}
		local headlight_rgb_text = color[1]..","..color[2]..","..color[3]

		local color = {255,255,255}
		local wheel_rgb_text = color[1]..","..color[2]..","..color[3]

		local paintjob_text = 3

		local taxation_start = 5

		sendMessage(localPlayer, "Вы получили "..info_png[val1][1].." "..val2, color_mes.orange)

		sqlite( "INSERT INTO car_db (number, model, taxation, frozen, evacuate, x, y, z, rot, fuel, car_rgb, headlight_rgb, paintjob, tune, stage, kilometrage, wheel, hydraulics, wheel_rgb, theft, inventory) VALUES ('"..val2.."', '"..car[job][1].."', '"..taxation_start.."', '0','0', '"..(x+2).."', '"..y.."', '"..z.."', '"..rot.."', '"..get("max_fuel").."', '"..car_rgb_text.."', '"..headlight_rgb_text.."', '"..paintjob_text.."', '0', '0', '0', '0', '0', '"..wheel_rgb_text.."', '0', '0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,')" )
		
		car_spawn(tostring(val2))
	end
end
--------------------------------------------------------------------------------------------------------

---------------------------------------авто-------------------------------------------------------------
function search_inv_car( vehicleid, id1, id2 )--цикл по поиску предмета в инв-ре авто
	local val = 0
	local plate = getVehiclePlateText ( vehicleid )

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 and array_car_2[plate][i+1] == id2 then
			val = val + 1
		end
	end

	return val
end

function search_inv_car_police( localPlayer, id )--цикл по выводу предметов
	local playername = getPlayerName ( localPlayer )

	for i=0,get("max_inv") do
		if array_car_1[id][i+1] ~= 0 then
			do_chat(localPlayer, info_png[ array_car_1[id][i+1] ][1].." "..array_car_2[id][i+1].." "..info_png[ array_car_1[id][i+1] ][2].." - "..playername)
		end
	end
end

function search_inv_car_2_parameter(vehicleid, id1)--вывод 2 параметра предмета в авто
	local plate = getVehiclePlateText ( vehicleid )

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 then
			return array_car_2[plate][i+1]
		end
	end

	return 0
end

function amount_inv_car_1_parameter(vehicleid, id1)--выводит коли-во предметов

	local plate = getVehiclePlateText ( vehicleid )
	local val = 0

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 then
			val = val + 1
		end
	end

	return val
end

function amount_inv_car_2_parameter(vehicleid, id1)--выводит сумму всех 2-ых параметров предмета

	local plate = getVehiclePlateText ( vehicleid )
	local val = 0

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 then
			val = val + array_car_2[plate][i+1]
		end
	end

	return val
end

function inv_car_empty(localPlayer, id1, id2, load_value)--выдача предмета в авто
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	local plate = getVehiclePlateText ( vehicleid )
	local count = 0

	if load_value then
		for i=0,get("max_inv") do
			if array_car_1[plate][i+1] == 0 then
				array_car_1[plate][i+1] = id1
				array_car_2[plate][i+1] = id2

				count = count+1

				triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )

				if state_inv_player[playername] == 1 then
					triggerClientEvent( localPlayer, "event_change_image", localPlayer, "car", i, array_car_1[plate][i+1] )
				end
			end
		end
	else
		for i=0,get("max_inv") do
			if array_car_1[plate][i+1] == 0 then
				array_car_1[plate][i+1] = id1
				array_car_2[plate][i+1] = id2

				count = count+1

				triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )

				if state_inv_player[playername] == 1 then
					triggerClientEvent( localPlayer, "event_change_image", localPlayer, "car", i, array_car_1[plate][i+1] )
				end
				break
			end
		end
	end

	if (count ~= 0) then
	
		local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
		if (result[1]["COUNT()"] == 1) then
		
			sqlite( "UPDATE car_db SET inventory = '"..save_inv(plate, "car").."' WHERE number = '"..plate.."'")
		end
	end

	return count
end

function inv_car_delet(localPlayer, id1, id2, delet_inv, unload_value, quest_bool)--удаления предмета в авто
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	local plate = getVehiclePlateText ( vehicleid )

	if delet_inv then
		triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
		state_inv_player[playername] = 0
	end

	if unload_value then
		local count = 0
		for i=0,get("max_inv") do
			if array_car_1[plate][i+1] == id1 and array_car_2[plate][i+1] == id2 then
				array_car_1[plate][i+1] = 0
				array_car_2[plate][i+1] = 0
				count = count+1

				triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )
			end
		end

		if count >= 20 then
			if quest_bool then
				quest_player(localPlayer, id1)
			end
		end
	else
		for i=0,get("max_inv") do
			if array_car_1[plate][i+1] == id1 and array_car_2[plate][i+1] == id2 then
				array_car_1[plate][i+1] = 0
				array_car_2[plate][i+1] = 0

				if quest_bool then
					quest_player(localPlayer, id1)
				end

				triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )
				break
			end
		end
	end

	local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
	if (result[1]["COUNT()"] == 1) then
		sqlite( "UPDATE car_db SET inventory = '"..save_inv(plate, "car").."' WHERE number = '"..plate.."'")
	end
end

function inv_car_delet_1_parameter(localPlayer, id1, delet_inv)--удаление всех предметов по ид
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	local plate = getVehiclePlateText ( vehicleid )

	if delet_inv then
		triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
		state_inv_player[playername] = 0
	end

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 then
			array_car_1[plate][i+1] = 0
			array_car_2[plate][i+1] = 0

			triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )
		end
	end

	local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
	if (result[1]["COUNT()"] == 1) then
		sqlite( "UPDATE car_db SET inventory = '"..save_inv(plate, "car").."' WHERE number = '"..plate.."'")
	end
end

function inv_car_throw_earth(vehicleid, id1, id2)--выброс предмета из авто на землю
	local plate = getVehiclePlateText ( vehicleid )
	local x,y,z = getElementPosition(vehicleid)
	local count = 0

	for i=0,get("max_inv") do
		if array_car_1[plate][i+1] == id1 and array_car_2[plate][i+1] == id2 then
			array_car_1[plate][i+1] = 0
			array_car_2[plate][i+1] = 0

			count = count+1

			max_earth = max_earth+1
			earth[max_earth] = {x,y,z,id1,id2}
		end
	end

	if count ~= 0 then
		local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
		if result[1]["COUNT()"] == 1 then
			sqlite( "UPDATE car_db SET inventory = '"..save_inv(plate, "car").."' WHERE number = '"..plate.."'")
		end

		setElementData(resourceRoot, "earth_data", earth)
	end
end

function setVehicleDoorOpenRatio_fun(localPlayer, value)--открывает багажник
	local vehicleid = getPlayerVehicle(localPlayer)
	if vehicleid then
		setVehicleDoorOpenRatio ( vehicleid, 1, value )
	end
end
addEvent("event_setVehicleDoorOpenRatio_fun", true)
addEventHandler("event_setVehicleDoorOpenRatio_fun", root, setVehicleDoorOpenRatio_fun)

function addVehicleUpgrade_fun( vehicleid, value, localPlayer, number )

	local playername = getPlayerName(localPlayer)
	local result = sqlite( "SELECT * FROM business_db WHERE number = '"..number.."'" )
	local plate = getVehiclePlateText ( vehicleid )
	local text = ""
	local prod = 1
	local cash = result[1]["price"]

	if prod <= result[1]["warehouse"] then
		if cash == 0 then
			sendMessage(localPlayer, "[ОШИБКА] Не установлена стоимость товара", color_mes.red)
			return
		end

		if cash <= search_inv_player_2_parameter(localPlayer, 1) then

			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
				if result[1]["tune"] ~= "0" then
					for k,v in pairs(split(result[1]["tune"], ",")) do
						local spl = split(v, ":")
						text = text..spl[1]..":"..spl[2]..":"..spl[3]..":"..spl[4]..":"..spl[5]..":"..spl[6]..":"..spl[7]..":"..spl[8]..","
					end
				end
			end

			text = text..value[1]..":"..value[2]..":"..value[3]..":"..value[4]..":"..value[5]..":"..value[6]..":"..value[7]..":"..value[8]..","

			local obj = createObject(value[1], 0,0,0, 0,0,0)
			attachElements(obj, vehicleid, value[2],value[3],value[4], value[5],value[6],value[7])
			setObjectScale(obj, value[8])

			setElementData(vehicleid, "tune_car", text)

			sendMessage(localPlayer, "Вы установили апгрейд за "..cash.."$", color_mes.orange)

			sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash.."' WHERE number = '"..number.."'")

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				sqlite( "UPDATE car_db SET tune = '"..text.."' WHERE number = '"..plate.."'")
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] На складе недостаточно товаров", color_mes.red)
	end
end
addEvent( "event_addVehicleUpgrade", true )
addEventHandler ( "event_addVehicleUpgrade", root, addVehicleUpgrade_fun )

function removeVehicleUpgrade_fun( vehicleid, localPlayer, number )

	local playername = getPlayerName(localPlayer)
	local result = sqlite( "SELECT * FROM business_db WHERE number = '"..number.."'" )
	local plate = getVehiclePlateText ( vehicleid )
	local text = "0"
	local prod = 1
	local cash = result[1]["price"]

	if prod <= result[1]["warehouse"] then
		if cash == 0 then
			sendMessage(localPlayer, "[ОШИБКА] Не установлена стоимость товара", color_mes.red)
			return
		end

		if cash <= search_inv_player_2_parameter(localPlayer, 1) then
			local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
			if  result[1]["tune"] == "0" then
				sendMessage(localPlayer, "[ОШИБКА] Нет установленного тюнинга", color_mes.red)
				return
			end

			for k,v in pairs(getAttachedElements ( vehicleid )) do
				destroyElement(v)
			end

			removeVehicleUpgrade(vehicleid, result[1]["hydraulics"])
			removeVehicleUpgrade(vehicleid, result[1]["wheel"])

			sendMessage(localPlayer, "Вы удалили все апгрейды за "..cash.."$", color_mes.orange)

			sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash.."' WHERE number = '"..number.."'")

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				sqlite( "UPDATE car_db SET tune = '"..text.."', wheel = '0', hydraulics = '0' WHERE number = '"..plate.."'")
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] На складе недостаточно товаров", color_mes.red)
	end
end
addEvent( "event_removeVehicleUpgrade", true )
addEventHandler ( "event_removeVehicleUpgrade", root, removeVehicleUpgrade_fun )
--------------------------------------------------------------------------------------------------------

---------------------------------------дом-------------------------------------------------------------
function search_inv_house( house, id1, id2 )--цикл по поиску предмета в инв-ре
	local val = 0

	for i=0,get("max_inv") do
		if array_house_1[house][i+1] == id1 and array_house_2[house][i+1] == id2 then
			val = val + 1
		end
	end

	return val
end

function search_inv_house_police( localPlayer, id )--цикл по выводу предметов
	local playername = getPlayerName ( localPlayer )

	for i=0,get("max_inv") do
		if array_house_1[id][i+1] ~= 0 then
			do_chat(localPlayer, info_png[ array_house_1[id][i+1] ][1].." "..array_house_2[id][i+1].." "..info_png[ array_house_1[id][i+1] ][2].." - "..playername)
		end
	end
end

function search_inv_house_2_parameter(house, id1)--вывод 2 параметра предмета

	for i=0,get("max_inv") do
		if array_house_1[house][i+1] == id1 then
			return array_house_2[house][i+1]
		end
	end

	return 0
end

function amount_inv_house_1_parameter(house, id1)--выводит коли-во предметов

	local val = 0

	for i=0,get("max_inv") do
		if array_house_1[house][i+1] == id1 then
			val = val + 1
		end
	end

	return val
end

function amount_inv_house_2_parameter(house, id1)--выводит сумму всех 2-ых параметров предмета

	local val = 0

	for i=0,get("max_inv") do
		if array_house_1[house][i+1] == id1 then
			val = val + array_house_2[house][i+1]
		end
	end

	return val
end
--------------------------------------------------------------------------------------------------------

function pickedUpWeaponCheck( localPlayer )
	local pickup = source
	local x,y,z = getElementPosition(localPlayer)
	local px,py,pz = getElementPosition(pickup)
	local playername = getPlayerName(localPlayer)

	if getElementModel(pickup) == get("business_icon") then
		for k,i in pairs(business_pos) do 
			if i[5] == pickup then
				local result = sqlite( "SELECT * FROM business_db WHERE number = '"..k.."'" )
				sendMessage(localPlayer, " ", color_mes.yellow)

				local s_sql = select_sqlite(43, result[1]["number"])
				if s_sql then
					sendMessage(localPlayer, "Владелец бизнеса "..s_sql, color_mes.yellow)
				else
					sendMessage(localPlayer, "Владелец бизнеса нету", color_mes.yellow)
				end

				sendMessage(localPlayer, "Тип "..result[1]["type"], color_mes.yellow)
				sendMessage(localPlayer, "Товаров на складе "..result[1]["warehouse"].." шт", color_mes.yellow)
				sendMessage(localPlayer, "Стоимость товара (надбавка в N раз) "..result[1]["price"].."$", color_mes.green)

				if search_inv_player(localPlayer, 43, result[1]["number"]) ~= 0 then
					sendMessage(localPlayer, "Состояние кассы "..split(result[1]["money"],".")[1].."$", color_mes.green)
					sendMessage(localPlayer, "Налог бизнеса оплачен на "..result[1]["taxation"].." дней", color_mes.yellow)
				end
				return
			end
		end

	elseif getElementModel(pickup) == get("house_icon") then
		for k,i in pairs(house_pos) do 
			if i[5] == pickup then
				local result = sqlite( "SELECT * FROM house_db WHERE number = '"..k.."'" )
				sendMessage(localPlayer, " ", color_mes.yellow)

				local s_sql = select_sqlite(25, result[1]["number"])
				if s_sql then
					sendMessage(localPlayer, "Владелец дома "..s_sql, color_mes.yellow)
				else
					sendMessage(localPlayer, "Владелец дома нету", color_mes.yellow)
				end

				if search_inv_player(localPlayer, 25, result[1]["number"]) ~= 0 then
					sendMessage(localPlayer, "Налог дома оплачен на "..result[1]["taxation"].." дней", color_mes.yellow)
				end
				return
			end
		end

	elseif getElementModel(pickup) == get("job_icon") then
		for k,v in pairs(interior_job) do 
			if isPointInCircle3D(v[6],v[7],v[8], x,y,z, v[12]) then
				sendMessage(localPlayer, " ", color_mes.yellow)
				sendMessage(localPlayer, v[2], color_mes.yellow)
				return
			end
		end

		for k,v in pairs(interior_job_pickup) do
			if pickup == v[1] then
				setElementPosition(localPlayer, v[2][1],v[2][2],v[2][3])
				return
			end
		end

	elseif getElementModel(pickup) == harvest_icon_complete then
		for k,v in pairs(harvest) do
			if v[6] == pickup and v[2] == 0 then
				if inv_player_empty( localPlayer, v[9], 1 ) then
					setPedAnimation(localPlayer, "BOMBER", "BOM_Plant", -1, true, false, false, false)

					setTimer(function ()
						if isElement(localPlayer) then
							setPedAnimation(localPlayer, nil, nil)
						end
					end, (10*1000), 1)

					destroyElement(v[6])
					destroyElement(v[7])

					harvest[k] = nil

					me_chat(localPlayer, playername.." собрал(а) "..info_png[v[9]][1])

					setElementData(resourceRoot, "harvest", harvest)
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end
				return
			end
		end
	end
end
addEventHandler( "onPickupHit", root, pickedUpWeaponCheck )

function sqlite_load(localPlayer, value)
	if value == "cow_farms_table1" then
		local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, 86).."'" )
		if result[1] then
			local farms = {
				{result[1]["number"], "Зарплата", result[1]["price"].."$"},
				{result[1]["number"], "Баланс", split(result[1]["money"],".")[1].."$"},
				{result[1]["number"], "Доход от продаж", result[1]["coef"].."%"},
				{result[1]["number"], "Налог", result[1]["taxation"].." дней"},
				{result[1]["number"], "Склад", result[1]["warehouse"].." тушек"},
				{result[1]["number"], "Склад", result[1]["prod"].." мешков с кормом"},
			}
			
			setElementData(localPlayer, "cow_farms_table1", farms)
		else
			setElementData(localPlayer, "cow_farms_table1", false)
		end

	elseif value == "business_table" then
		local result = sqlite( "SELECT * FROM business_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, 43).."'" )
		if result[1] then
			local farms = {
				{result[1]["number"], "Цена на товар (надбавка в N раз)", result[1]["price"].."$"},
				{result[1]["number"], "Баланс", split(result[1]["money"],".")[1].."$"},
				{result[1]["number"], "Налог", result[1]["taxation"].." дней"},
				{result[1]["number"], "Склад", result[1]["warehouse"].." продуктов"},
			}
			
			setElementData(localPlayer, "business_table", farms)
		else
			setElementData(localPlayer, "business_table", false)
		end

	elseif value == "quest_table" then
		setElementData(localPlayer, "quest_table", quest_table)

	elseif value == "auc" then
		local result = sqlite( "SELECT * FROM auction" )
		setElementData(localPlayer, "auc", result)

	elseif value == "carparking_table" then
		local result_car = sqlite( "SELECT * FROM car_db WHERE taxation = '0'" )
		setElementData(localPlayer, "carparking_table", result_car)

	elseif value == "cow_farms_table2" then
		local result_cow_farms = sqlite( "SELECT * FROM cow_farms_db" )
		setElementData(localPlayer, "cow_farms_table2", result_cow_farms)

	elseif value == "account_db" then
		local result = sqlite( "SELECT * FROM account" )
		setElementData(localPlayer, "account_db", result)

	elseif value == "house_db" then
		local result = sqlite( "SELECT * FROM house_db" )
		setElementData(localPlayer, "house_db", result)

	elseif value == "business_db" then
		local result = sqlite( "SELECT * FROM business_db" )
		setElementData(localPlayer, "business_db", result)

	elseif value == "car_db" then
		local result = sqlite( "SELECT * FROM car_db" )
		setElementData(localPlayer, "car_db", result)
	end
end
addEvent("event_sqlite_load", true)
addEventHandler("event_sqlite_load", root, sqlite_load)

function auction_buy_sell(localPlayer, value, i, id1, id2, money, name_buy)--продажа покупка вещей
	local playername = getPlayerName ( localPlayer )
	local randomize = random(1,99999)
	local count = 0

	if value == "sell" then
		if inv_player_delet(localPlayer, id1, id2) then
			while (true) do
				local result = sqlite( "SELECT COUNT() FROM auction WHERE i = '"..randomize.."'" )
				if result[1]["COUNT()"] == 0 then
					break
				else
					randomize = random(1,99999)
				end
			end

			sendMessage(localPlayer, "Вы выставили на аукцион "..info_png[id1][1].." "..id2.." "..info_png[id1][2].." за "..money.."$", color_mes.green)

			sqlite( "INSERT INTO auction (i, name_sell, id1, id2, money, name_buy) VALUES ('"..randomize.."', '"..playername.."', '"..id1.."', '"..id2.."', '"..money.."', '"..name_buy.."')" )
		else
			sendMessage(localPlayer, "[ОШИБКА] У вас нет такого предмета", color_mes.red)
		end

	elseif value == "buy" then
		local result = sqlite( "SELECT COUNT() FROM auction WHERE i = '"..i.."'" )

		if result[1]["COUNT()"] == 1 then
			local result = sqlite( "SELECT * FROM auction WHERE i = '"..i.."'" )

			if (result[1]["name_buy"] ~= playername and result[1]["name_buy"] ~= "all") then
			
				sendMessage(localPlayer, "[ОШИБКА] Вы не можете купить этот предмет", color_mes.red)
				return
			end

			if search_inv_player_2_parameter(localPlayer, 1) >= result[1]["money"] then

				if inv_player_empty(localPlayer, result[1]["id1"], result[1]["id2"]) then
					sendMessage(localPlayer, "Вы купили у "..result[1]["name_sell"].." "..info_png[result[1]["id1"]][1].." "..result[1]["id2"].." "..info_png[result[1]["id1"]][2].." за "..result[1]["money"].."$", color_mes.orange)

					inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-result[1]["money"], playername )

					for i,localPlayer in pairs(getElementsByType("player")) do
						local playername_sell = getPlayerName(localPlayer)
						if playername_sell == result[1]["name_sell"] then
							sendMessage(localPlayer, playername.." купил у вас "..info_png[result[1]["id1"]][1].." "..result[1]["id2"].." "..info_png[result[1]["id1"]][2].." за "..result[1]["money"].."$", color_mes.green)
							inv_server_load( localPlayer, "player", 0, 1, array_player_2[playername_sell][1]+result[1]["money"], playername_sell )
							count = count+1
							break
						end
					end

					if count == 0 then
						local result_sell = sqlite( "SELECT COUNT() FROM account WHERE name = '"..result[1]["name_sell"].."'" )
						if result_sell[1]["COUNT()"] == 1 then
							array_player_1[result[1]["name_sell"]] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
							array_player_2[result[1]["name_sell"]] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

							local result_sell = sqlite( "SELECT * FROM account WHERE name = '"..result[1]["name_sell"].."'" )
							load_inv(result[1]["name_sell"], "player", result_sell[1]["inventory"])

							array_player_2[result[1]["name_sell"]][1] = array_player_2[result[1]["name_sell"]][1]+result[1]["money"]

							sqlite( "UPDATE account SET inventory = '"..save_inv(result[1]["name_sell"], "player").."' WHERE name = '"..result[1]["name_sell"].."'")
						end
					end

					sqlite( "DELETE FROM auction WHERE i = '"..i.."'" )
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Лот не найден", color_mes.red)
		end

	elseif value == "return" then
		local result = sqlite( "SELECT COUNT() FROM auction WHERE i = '"..i.."'" )

		if result[1]["COUNT()"] == 1 then
			local result = sqlite( "SELECT * FROM auction WHERE i = '"..i.."'" )

			if playername == result[1]["name_sell"] then

				if inv_player_empty(localPlayer, result[1]["id1"], result[1]["id2"]) then
					sendMessage(localPlayer, "Вы забрали "..info_png[result[1]["id1"]][1].." "..result[1]["id2"].." "..info_png[result[1]["id1"]][2], color_mes.orange)

					sqlite( "DELETE FROM auction WHERE i = '"..i.."'" )
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Имена не совпадают", color_mes.red)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Лот не найден", color_mes.red)
		end
	end
end
addEvent( "event_auction_buy_sell", true )
addEventHandler ( "event_auction_buy_sell", root, auction_buy_sell )
---------------------------------------------------------------------------------------------------------


---------------------------------------магазины-------------------------------------------------------------
function buy_subject_fun( localPlayer, text, number, value )
	local playername = getPlayerName(localPlayer)

	if value == "pd" then

		for k,v in pairs(sub_cops) do
			if v[1] == text then
				if inv_player_empty(localPlayer, v[3], v[2]) then
					sendMessage(localPlayer, "Вы получили "..text, color_mes.orange)
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end
				return
			end
		end

		if text == weapon_cops[39][1] then
			if inv_player_empty(localPlayer, 39, 1) then
				sendMessage(localPlayer, "Вы получили "..text, color_mes.orange)
			else
				sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
			end
			return
		end

		if search_inv_player_2_parameter(localPlayer, 50) ~= getElementData(localPlayer, "player_id") then
			sendMessage(localPlayer, "[ОШИБКА] У вас нет лицензии на оружие, приобрести её можно в Мэрии", color_mes.red)
			return
		end

		for k,v in pairs(weapon_cops) do
			if v[1] == text then
				if inv_player_empty(localPlayer, k, v[4]) then
					sendMessage(localPlayer, "Вы получили "..text, color_mes.orange)
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end
			end
		end

		return

	elseif value == "mer" then
		for k,v in pairs(mayoralty_shop) do
			if v[1] == text then
				if v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
					if v[4] == 10 or v[4] == 2 or v[4] == 50 then
						if inv_player_empty(localPlayer, v[4], getElementData(localPlayer, "player_id")) then
							sendMessage(localPlayer, "Вы купили "..text.." за "..v[3].."$", color_mes.orange)

							inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(v[3]), playername )
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					else
						if inv_player_empty(localPlayer, v[4], v[2]) then
							sendMessage(localPlayer, "Вы купили "..text.." за "..v[3].."$", color_mes.orange)

							inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(v[3]), playername )
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					end
				else
					sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				end
			end
		end
		
		return

	elseif value == "giuseppe" then
		for k,v in pairs(giuseppe) do
			if v[1] == text then
				if k >= 5 and k <= 14 then
					local count = false
					local name_mafia_skin = ""
					for k,j in pairs(name_mafia[v[2]][2]) do
						name_mafia_skin = name_mafia_skin..j..","
						if getElementModel(localPlayer) == j then
							count = true
							if v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
								if inv_player_empty(localPlayer, v[4], v[2]) then
									sendMessage(localPlayer, "Вы купили "..text.." за "..v[3].."$", color_mes.orange)

									inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(v[3]), playername )
								else
									sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
								end
							else
								sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
							end
						end
					end

					if not count then
						sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде "..name_mafia_skin, color_mes.red)
					end
				else
					if v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
						if inv_player_empty(localPlayer, v[4], v[2]) then
							sendMessage(localPlayer, "Вы купили "..text.." за "..v[3].."$", color_mes.orange)

							inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(v[3]), playername )
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					else
						sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
					end
				end

				return
			end
		end
		
		return
	end

	local result = sqlite( "SELECT * FROM business_db WHERE number = '"..number.."'" )
	local prod = 1
	local cash = result[1]["price"]

	if prod <= result[1]["warehouse"] then
		if cash == 0 then
			sendMessage(localPlayer, "[ОШИБКА] Не установлена стоимость товара (надбавка в N раз)", color_mes.red)
			return
		end

			if value == 1 then
				if search_inv_player_2_parameter(localPlayer, 50) ~= getElementData(localPlayer, "player_id") then
					sendMessage(localPlayer, "[ОШИБКА] У вас нет лицензии на оружие, приобрести её можно в Мэрии", color_mes.red)
					return
				end

				for k,v in pairs(weapon) do
					if v[1] == text then
						if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
							if inv_player_empty(localPlayer, k, v[4]) then
								sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)

								sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

								inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )
							else
								sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
							end
						else
							sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
						end
					end
				end

			elseif value == 2 then
				if text == "мужская одежда" or text == "женская одежда" then
					return
				end

				if cash <= search_inv_player_2_parameter(localPlayer, 1) then
					if inv_player_empty(localPlayer, 27, text) then
						sendMessage(localPlayer, "Вы купили "..text.." скин за "..cash.."$", color_mes.orange)

						sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash.."' WHERE number = '"..number.."'")

						inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )
					else
						sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
					end
				else
					sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				end

			elseif value == 3 then
				local v,k = {shop[104][1], shop[104][2], shop[104][3]},104--покупка лото
				local randomize,count = random(1,1000),false

				while true do
					for k,v in pairs(loto[2]) do
						if v == randomize then
							count = true
						end
					end

					if not count then
						break
					else
						randomize,count = random(1,1000),false
					end
				end

				if v[1] == text then
					if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
						if inv_player_empty(localPlayer, k, randomize) then
							sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)

							sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

							inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )

							table.insert(loto[2], randomize)
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					else
						sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
					end
					return
				end

				local v,k,key = {shop[115][1], shop[115][2], shop[115][3]},115,116--покупка ящика
				local result = sqlite( "SELECT COUNT() FROM box_db")
				if v[1] == text then
					if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
						if search_inv_player(localPlayer, 0, 0) >= 2 then
							local b = result[1]["COUNT()"]+1

							inv_player_empty(localPlayer, k, b)
							inv_player_empty(localPlayer, key, b)

							array_box_1[b] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
							array_box_2[b] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

							sqlite( "INSERT INTO box_db (number, inventory) VALUES ('"..b.."', '0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,')" )

							sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)
							sendMessage(localPlayer, "Вы получили "..info_png[key][1].." "..b, color_mes.orange)

							sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

							inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					else
						sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
					end
					return
				end

				for k,v in pairs(shop) do
					if v[1] == text then
						if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
							if inv_player_empty(localPlayer, k, v[2]) then
								sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)

								sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

								inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )
							else
								sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
							end
						else
							sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
						end
					end
				end

			elseif value == 4 then
				for k,v in pairs(gas) do
					if v[1] == text then
						if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
							if inv_player_empty(localPlayer, k, v[2]) then
								sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)

								sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

								inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )
							else
								sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
							end
						else
							sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
						end
					end
				end

			elseif value == 5 then
				for k,v in pairs(repair_shop) do
					if v[1] == text then
						if cash*v[3] <= search_inv_player_2_parameter(localPlayer, 1) then
							if inv_player_empty(localPlayer, v[4], v[2]) then
								sendMessage(localPlayer, "Вы купили "..text.." за "..cash*v[3].."$", color_mes.orange)

								sqlite( "UPDATE business_db SET warehouse = warehouse - '"..prod.."', money = money + '"..cash*v[3].."' WHERE number = '"..number.."'")

								inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*v[3]), playername )
							else
								sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
							end
						else
							sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
						end
					end
				end

			end

	else
		sendMessage(localPlayer, "[ОШИБКА] На складе недостаточно товаров", color_mes.red)
	end	
end
addEvent( "event_buy_subject_fun", true )
addEventHandler ( "event_buy_subject_fun", root, buy_subject_fun )
------------------------------------------------------------------------------------------------------------


--------------------------эвент по кассе для бизнесов-------------------------------------------------------
function till_fun( localPlayer, value, money )
	local playername = getPlayerName(localPlayer)
	local doc = 43

	if value == "Баланс" then
		if money == 0 then
			return
		end

		if money < 1 then
			local result = sqlite( "SELECT * FROM business_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )
			if not result[1] then
				return
			end

			if (money*-1) <= result[1]["money"] then
				sqlite( "UPDATE business_db SET money = money - '"..(money*-1).."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'")

				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+(money*-1), playername )

				sendMessage(localPlayer, "Вы забрали из кассы "..(money*-1).."$", color_mes.green)
			else
				sendMessage(localPlayer, "[ОШИБКА] В кассе недостаточно средств", color_mes.red)
			end

		else
			local result = sqlite( "SELECT * FROM business_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )
			if not result[1] then
				return
			end

			if money <= search_inv_player_2_parameter(localPlayer, 1) then
				sqlite( "UPDATE business_db SET money = money + '"..money.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'")

				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-money, playername )

				sendMessage(localPlayer, "Вы положили в кассу "..money.."$", color_mes.orange)
			else
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
			end
		end

	elseif value == "Цена на товар (надбавка в N раз)" then
		local result = sqlite( "SELECT * FROM business_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

		if not result[1] then
			return
		elseif money < 1 then
			return
		end

		sqlite( "UPDATE business_db SET price = '"..money.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'")

		sendMessage(localPlayer, "Вы установили стоимость товара "..money.."$", color_mes.yellow)

	end
end
addEvent( "event_till_fun", true )
addEventHandler ( "event_till_fun", root, till_fun )


----------------------------------крафт предметов -----------------------------------------------------------
function craft_fun( localPlayer, text )
	local playername = getPlayerName(localPlayer)

	if enter_house[playername][1] == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Вы не в доме", color_mes.red)
		return
	end

	for k,v in pairs(sqlite( "SELECT * FROM house_db" )) do 
		if search_inv_player(localPlayer, 25, v["number"]) ~= 0 then

			for k,v in pairs(craft_table) do
				if text == v[1] then
					local split_sub = split(v[3], ",")
					local split_res = split(v[4], ",")
					local split_sub_create = split(v[5], ",")
					local len = #split_sub
					local count = 0

					for i=1,len do
						if search_inv_player(localPlayer, tonumber(split_sub[i]), tonumber(split_res[i])) >= 1 then
							count = count + 1
						end
					end
					
					if count == len then
						if inv_player_empty(localPlayer, tonumber(split_sub_create[1]), tonumber(split_sub_create[2])) then

							for i=1,len do
								if inv_player_delet(localPlayer, tonumber(split_sub[i]), tonumber(split_res[i])) then
								end
							end

							sendMessage(localPlayer, "Вы создали "..v[1], color_mes.orange)
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
						end
					else
						sendMessage(localPlayer, "[ОШИБКА] Недостаточно ресурсов", color_mes.red)
					end
				end
			end

			return
		end
	end

	sendMessage(localPlayer, "[ОШИБКА] У вас нет ключа от дома", color_mes.red)
end
addEvent( "event_craft_fun", true )
addEventHandler ( "event_craft_fun", root, craft_fun )
-------------------------------------------------------------------------------------------------------------


----------------------------------------------скотобойня-----------------------------------------------------
function cow_farms(localPlayer, value, val1, val2)
	local playername = getPlayerName(localPlayer)
	local x,y,z = getElementPosition(localPlayer)
	local cash = 50000
	local doc = 86
	local lic = 87

	if value == "buy" then
		local result = sqlite( "SELECT COUNT() FROM cow_farms_db" )
		result = result[1]["COUNT()"]+1
		if cash*result > search_inv_player_2_parameter(localPlayer, 1) then
			sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств, необходимо "..cash*result.."$", color_mes.red)
			return
		end

		if inv_player_empty(localPlayer, doc, result) then
			sqlite( "INSERT INTO cow_farms_db (number, price, coef, money, taxation, warehouse, prod) VALUES ('"..result.."', '0', '50', '0', '5', '0', '0')" )

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash*result, playername )

			sendMessage(localPlayer, "Вы купили скотобойню за "..cash*result.."$", color_mes.orange)

			sendMessage(localPlayer, "Вы получили "..info_png[doc][1].." "..result.." "..info_png[doc][2], color_mes.svetlo_zolotoy)
		else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
		end

	elseif value == "menu" then

		if val1 == "Зарплата" then
			if val2 < 1 then
				return
			end

			local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

			if not result[1] then
				return
			end

			sqlite( "UPDATE cow_farms_db SET price = '"..val2.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

			sendMessage(localPlayer, "Вы установили зарплату "..val2.."$", color_mes.yellow)

		elseif val1 == "Доход от продаж" then
			if val2 < 1 or val2 > 100 then
				return
			end

			local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

			if not result[1] then
				return
			end

			sqlite( "UPDATE cow_farms_db SET coef = '"..val2.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

			sendMessage(localPlayer, "Вы установили доход от продаж "..val2.."%", color_mes.yellow)

		elseif val1 == "Баланс" then
			if val2 == 0 then
				return
			end

			if val2 < 1 then
				local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

				if not result[1] then
					return
				end

				if (val2*-1) <= result[1]["money"] then
					inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+(val2*-1), playername )

					sqlite( "UPDATE cow_farms_db SET money = money - '"..(val2*-1).."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

					sendMessage(localPlayer, "Вы забрали из кассы "..(val2*-1).."$", color_mes.green)
				else
					sendMessage(localPlayer, "[ОШИБКА] Недостаточно средств на балансе бизнеса", color_mes.red)
				end
			else
				if val2 <= search_inv_player_2_parameter(localPlayer, 1) then
					local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

					if not result[1] then
						return
					end

					inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-val2, playername )

					sqlite( "UPDATE cow_farms_db SET money = money + '"..val2.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

					sendMessage(localPlayer, "Вы положили в кассу "..val2.."$", color_mes.orange)
				else
					sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				end
			end

		elseif val1 == "Налог" then
			local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'" )

			if not result[1] then
				return
			end

			if search_inv_player(localPlayer, 60, 7) ~= 0 then
				if inv_player_delet(localPlayer, 60, 7) then
					sqlite( "UPDATE cow_farms_db SET taxation = taxation + '7' WHERE number = '"..search_inv_player_2_parameter(localPlayer, doc).."'")

					sendMessage(localPlayer, "Вы оплатили налог "..search_inv_player_2_parameter(localPlayer, doc).." скотобойни", color_mes.yellow)
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] У вас нет "..info_png[60][1].." 7 "..info_png[60][2], color_mes.red)
			end
		end

	elseif value == "job" then
		give_subject(localPlayer, "player", lic, val1, true)

	elseif value == "load" then
		local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'" )

		if not result[1] then
			return false
		elseif result[1]["warehouse"]-val1 < 0 then
			sendMessage(localPlayer, "[ОШИБКА] Склад пуст", color_mes.red)
			return false
		end

		sqlite( "UPDATE cow_farms_db SET warehouse = warehouse - '"..val1.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'")

		return true

	elseif value == "unload" then
		local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'" )

		if not isPointInCircle3D(x,y,z, down_car_subject[3][1],down_car_subject[3][2],down_car_subject[3][3], down_car_subject[3][4]) then
			return false
		end

		if not result[1] then
			return true
		end

		inv_car_delet(localPlayer, 88, val2, true, true)

		local money = val1*val2

		local cash2 = (money*((100-result[1]["coef"])/100))
		local cash = (money*(result[1]["coef"]/100))

		inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+cash, playername )

		sendMessage(localPlayer, "Вы разгрузили из т/с "..info_png[88][1].." "..val1.." шт за "..cash.."$", color_mes.green)

		sqlite( "UPDATE cow_farms_db SET money = money + '"..cash2.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'")

		return true

	elseif value == "unload_prod" then
		local money = val1*val2
		local result = sqlite( "SELECT * FROM cow_farms_db WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'" )

		if not isPointInCircle3D(x,y,z, down_car_subject[4][1],down_car_subject[4][2],down_car_subject[4][3], down_car_subject[4][4]) then
			return false
		end

		if not result[1] then
			return true
		elseif result[1]["money"] < money then
			sendMessage(localPlayer, "[ОШИБКА] Недостаточно средств на балансе бизнеса", color_mes.red)
			return true
		elseif result[1]["prod"] >= get("max_cf") then
			sendMessage(localPlayer, "[ОШИБКА] Склад полон", color_mes.red)
			return true
		end

		inv_car_delet(localPlayer, 89, val2, true, true)

		inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money, playername )

		sendMessage(localPlayer, "Вы разгрузили из т/с "..info_png[89][1].." "..val1.." шт за "..money.."$", color_mes.green)

		sqlite( "UPDATE cow_farms_db SET money = money - '"..money.."', prod = prod + '"..val1.."' WHERE number = '"..search_inv_player_2_parameter(localPlayer, lic).."'")

		return true
	end
end
addEvent( "event_cow_farms", true )
addEventHandler ( "event_cow_farms", root, cow_farms )
-------------------------------------------------------------------------------------------------------------

function displayLoadedRes ( res )--старт ресурсов
	setTime(0,0)
	setGameType ( "discord.gg/000000" )--ссылка на дискорд
	removeWorldModel(1283, 999999, 0, 0, 0)
	removeWorldModel(1315, 999999, 0, 0, 0)
	removeWorldModel(1284, 999999, 0, 0, 0)
	removeWorldModel(1350, 999999, 0, 0, 0)
	removeWorldModel(1351, 999999, 0, 0, 0)
	removeWorldModel(3516, 999999, 0, 0, 0)
	removeWorldModel(1352, 999999, 0, 0, 0)
	removeWorldModel(3855, 999999, 0, 0, 0)

	setTimer(debuginfo, 1000, 0)--дебагинфа
	setTimer(need, 60000, 0)--уменьшение потребностей
	setTimer(need_1, 10000, 0)--смена скина на бомжа
	setTimer(fuel_down, 1000, 0)--система топлива
	setTimer(set_weather, 1000, 0)--погода сервера
	setTimer(prison, 60000, 0)--таймер заключения в тюрьме
	setTimer(prison_timer, 1000, 0)--античит если не в тюрьме
	setTimer(pay_taxation, 60000, 0)--списание налогов

	setWeather(tomorrow_weather)
	setGlitchEnabled ( "quickreload", true )


	for k,v in pairs(no_ped_damage) do--заморозка нпс
		setElementFrozen(v, true)
	end
		

	local result = sqlite( "SELECT COUNT() FROM account" )
	print("[account] "..result[1]["COUNT()"])


	local result = sqlite( "SELECT COUNT() FROM account WHERE ban != '0'" )
	print("[account_banned] "..result[1]["COUNT()"])


	local result = sqlite( "SELECT COUNT() FROM banserial_list" )
	print("[account_banserial] "..result[1]["COUNT()"])


	carnumber_number = 0
	for k,v in pairs(sqlite( "SELECT * FROM car_db" )) do
		car_spawn(v["number"])
	end
	print("[number_car_spawn] "..carnumber_number)


	local house_number = 0
	for k,v in pairs(sqlite( "SELECT * FROM house_db" )) do
		local h = v["number"]
		house_pos[v["number"]] = {v["x"], v["y"], v["z"], createBlip ( v["x"], v["y"], v["z"], 32, 0, 0,0,0,0, 0, get("max_blip") ), createPickup (  v["x"], v["y"], v["z"], 3, get("house_icon"), 10000 )}

		array_house_1[h] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		array_house_2[h] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

		load_inv(h, "house", v["inventory"])

		house_number = house_number+1
	end
	print("[house_number] "..house_number)


	local box_number = 0
	for k,v in pairs(sqlite( "SELECT * FROM box_db" )) do
		local h = v["number"]

		array_box_1[h] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		array_box_2[h] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

		load_inv(h, "box", v["inventory"])

		box_number = box_number+1
	end
	print("[box_number] "..box_number)


	local business_number = 0
	for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do
		business_pos[v["number"]] = {v["x"], v["y"], v["z"], createBlip ( v["x"], v["y"], v["z"], interior_business[v["interior"]][6], 0, 0,0,0,0, 0, get("max_blip") ), createPickup ( v["x"], v["y"], v["z"], 3, get("business_icon"), 10000 )}

		business_number = business_number+1
	end
	print("[business_number] "..business_number)
		

	local cow_farms_db = 0
	for k,v in pairs(sqlite( "SELECT * FROM cow_farms_db" )) do
		cow_farms_db = cow_farms_db+1
	end
	print("[cow_farms_db] "..cow_farms_db)
	print("")


	for k,v in pairs(sqlite( "SELECT * FROM guns_zone" )) do
		local r,g,b = getTeamColor ( name_mafia[v["mafia"]][1] )
		guns_zone[v["number"]] = {createRadarArea (v["x1"], v["y1"], v["x2"], v["y2"], r,g,b, 100), v["mafia"]}
	end


	--создание блипов
	for k,v in pairs(interior_job) do 
		createBlip ( v[6], v[7], v[8], v[9], 0, 0,0,0,0, 0, get("max_blip") )
		createPickup ( v[6], v[7], v[8], 3, get("job_icon"), 10000 )
	end

	createBlip ( 2308.81640625,-13.25,26.7421875, 8, 0, 0,0,0,0, 0, get("max_blip") )--банк штата

	for k,v in pairs(up_car_subject) do
		createBlip ( v[1], v[2], v[3], 51, 0, 0,0,0,0, 0, get("max_blip") )
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
	end

	for k,v in pairs(down_car_subject) do
		createBlip ( v[1], v[2], v[3], 52, 0, 0,0,0,0, 0, get("max_blip") )
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
	end

	for k,v in pairs(down_car_subject_pos) do
		createBlip ( v[1], v[2], v[3], 52, 0, 0,0,0,0, 0, get("max_blip") )
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
	end

	for k,v in pairs(t_s_salon) do
		createBlip ( v[1], v[2], v[3], v[4], 0, 0,0,0,0, 0, get("max_blip") )--салоны продажи
	end

	for k,v in pairs(station) do
		createBlip ( v[1], v[2], v[3], 42, 0, 0,0,0,0, 0, get("max_blip") )--вокзалы
	end

	for k,v in pairs(hospital_spawn) do
		createBlip ( v[1], v[2], v[3], 22, 0, 0,0,0,0, 0, get("max_blip") )--больницы
	end

	for j=0,1 do
		for i=0,4 do
			local obj = createObject(2804, 954.90002+(j*6.5),2143.5-(3*i),1010.9, 0,180,270)
			setElementInterior(obj, interior_job[1][1])
			setElementDimension(obj, interior_job[1][10])

			local obj = createObject(941, 955.79999+(j*6.5),2143.6001-(3*i),1010.5, 0,0,0)
			setElementInterior(obj, interior_job[1][1])
			setElementDimension(obj, interior_job[1][10])

			anim_player_subject[#anim_player_subject+1] = {956.0166015625+(j*6.5),2142.6650390625-(3*i),1011.0181274414, 1, 30, 48, 100, "knife", "knife_4", 1, 1, 10}
		end
	end


	--создание маркеров
	for k,v in pairs(up_player_subject) do
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
		setElementInterior(marker, v[7])
		setElementDimension(marker, v[8])

		if v[7] == 0 then
			createBlip ( v[1], v[2], v[3], 51, 0, 0,0,0,0, 0, get("max_blip") )
		end
	end

	for k,v in pairs(down_player_subject) do
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
		setElementInterior(marker, v[6])
		setElementDimension(marker, v[7])

		if v[6] == 0 then
			createBlip ( v[1], v[2], v[3], 52, 0, 0,0,0,0, 0, get("max_blip") )
		end
	end

	for k,v in pairs(anim_player_subject) do
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
		setElementInterior(marker, v[10])
		setElementDimension(marker, v[11])
	end

	for k,v in pairs(t_s_salon) do
		local marker = createMarker ( v[1], v[2], v[3]-1, "cylinder", 1.0, color_mes.yellow[1],color_mes.yellow[2],color_mes.yellow[3] )
	end

	--[[for j=0,29 do
		for i=0,16 do
			local x,y,z = -181.125-(i*5)+(j*1.92),-83.888671875+(1.66*i)+(j*5),3.11-1.5
			local obj = createObject(323, x,y,z, 0,180,0)
			grass_pos[#grass_pos+1] = {obj, x,y,z}
		end
	end]]


	setElementData(resourceRoot, "zakon_alcohol", get("zakon_alcohol"))
	setElementData(resourceRoot, "zakon_drugs", get("zakon_drugs"))
	setElementData(resourceRoot, "craft_table", craft_table)
	setElementData(resourceRoot, "shop", shop)
	setElementData(resourceRoot, "gas", gas)
	setElementData(resourceRoot, "giuseppe", giuseppe)
	setElementData(resourceRoot, "interior_business", interior_business)
	setElementData(resourceRoot, "mayoralty_shop", mayoralty_shop)
	setElementData(resourceRoot, "weapon_cops", weapon_cops)
	setElementData(resourceRoot, "sub_cops", sub_cops)
	setElementData(resourceRoot, "house_bussiness_radius", get("house_bussiness_radius"))
	setElementData(resourceRoot, "name_mafia", name_mafia)
	setElementData(resourceRoot, "interior_job", interior_job)
	setElementData(resourceRoot, "cash_car", cash_car)
	setElementData(resourceRoot, "cash_boats", cash_boats)
	setElementData(resourceRoot, "cash_helicopters", cash_helicopters)
	setElementData(resourceRoot, "repair_shop", repair_shop)
	setElementData(resourceRoot, "weapon_shop", weapon_shop)
	setElementData(resourceRoot, "house_pos", house_pos)
	setElementData(resourceRoot, "business_pos", business_pos)
	setElementData(resourceRoot, "tomorrow_weather_data", tomorrow_weather)
	setElementData(resourceRoot, "earth_data", earth)
	setElementData(resourceRoot, "info_png", info_png)
	setElementData(resourceRoot, "harvest", harvest)
	setElementData(resourceRoot, "update_db_rang", get("update_db_rang"))
	setElementData(resourceRoot, "hospital_spawn", hospital_spawn)
	setElementData(resourceRoot, "color_mes", color_mes)
	setElementData(resourceRoot, "weapon", weapon)
	setElementData(resourceRoot, "up_car_subject", up_car_subject)
	setElementData(resourceRoot, "down_car_subject_pos", down_car_subject_pos)
	setElementData(resourceRoot, "up_player_subject", up_player_subject)
	setElementData(resourceRoot, "down_player_subject", down_player_subject)
end
addEventHandler ( "onResourceStart", resourceRoot, displayLoadedRes )

addEventHandler("onPlayerJoin", root,--конект игрока на сервер
function()
	local localPlayer = source
	local playername = getPlayerName ( localPlayer )
	local serial = getPlayerSerial(localPlayer)
	local ip = getPlayerIP ( localPlayer )
	setPlayerScriptDebugLevel(localPlayer, 3)

	--o_pos(localPlayer)

	array_player_1[playername] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	array_player_2[playername] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

	state_inv_player[playername] = 0
	state_gui_window[playername] = 0
	logged[playername] = 0
	enter_house[playername] = {0,0}
	enter_business[playername] = 0
	enter_job[playername] = 0
	speed_car_device[playername] = 0
	arrest[playername] = 0
	crimes[playername] = 0
	robbery_player[playername] = 0
	robbery_timer[playername] = 0
	gps_device[playername] = 0
	job[playername] = 0
	armour[playername] = 0
	game[playername] = {}
	accept_player[playername] = {false,false,false,false}
	drone[playername] = 0

	--нужды
	alcohol[playername] = 0
	satiety[playername] = 0
	hygiene[playername] = 0
	sleep[playername] = 0
	drugs[playername] = 0

	local result = sqlite( "SELECT COUNT() FROM banserial_list WHERE serial = '"..serial.."'" )
	if result[1]["COUNT()"] == 1 then
		local result = sqlite( "SELECT * FROM banserial_list WHERE serial = '"..serial.."'" )
		kickPlayer(localPlayer, "ban serial reason: "..result[1]["reason"])
		return
	end

	local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..playername.."'" )
	if result[1]["COUNT()"] == 1 then
		local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )
		if result[1]["ban"] ~= "0" then
			kickPlayer(localPlayer, "ban player reason: "..result[1]["ban"])
			return
		end
	end

	if not string.find(playername, "^%u%l+_%u%l+$") then
		kickPlayer(localPlayer, "Неправильный формат ника (Имя_Фамилия)")
		return
	end

	----бинд клавиш----
	bindKey(localPlayer, "tab", "down", tab_down )
	bindKey(localPlayer, "e", "down", e_down )
	bindKey(localPlayer, "x", "down", x_down )
	bindKey(localPlayer, "lalt", "down", left_alt_down )
	bindKey(localPlayer, "h", "down", h_down )

	setPlayerHudComponentVisible ( localPlayer, "money", false )
	setPlayerHudComponentVisible ( localPlayer, "health", false )
	setPlayerHudComponentVisible ( localPlayer, "vehicle_name", true )
	setPlayerNametagShowing ( localPlayer, false )
	setPlayerBlurLevel ( localPlayer, 0 )

	for _, stat in pairs({ 22, 24, 225, 70, 71, 72, 73, 74, 76, 77, 78, 79 }) do
		setPedStat(localPlayer, stat, 1000)
	end

	for _, stat in pairs({ 69, 75 }) do
		setPedStat(localPlayer, stat, 998)
	end

	sendMessage(localPlayer, "[TIPS] F1 - скрыть или показать курсор", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] F2 - скрыть или показать худ", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] F3 - меню т/с и анимаций", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] TAB - открыть инвентарь, ПКМ - использовать предмет, чтобы выкинуть переместите его за пределы инвентаря", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] X - крафт предметов", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] Листать чат page up и page down", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] Команды сервера находятся в WIKI в планшете", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] Первоначальная работа находится в ЛВ мясокомбинат", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] Граждане не имеющий дом, могут помыться и выспаться в отелях", color_mes.color_tips)
	sendMessage(localPlayer, "[TIPS] Права можно получить в Мэрии", color_mes.color_tips)

	count_player = count_player+1
	setElementData(localPlayer, "player_id", count_player)
	setElementData(localPlayer, "fuel_data", 0)
	setElementData(localPlayer, "kilometrage_data", 0)
	setElementData(localPlayer, "quest_select", "0:0")
	setElementData(localPlayer, "radar_visible", true)
	setElementData(localPlayer, "task", false)
	setElementData(localPlayer, "is_chat_open", 0)
	setElementData(localPlayer, "afk", 0)
end)

function quitPlayer ( quitType )--дисконект игрока с сервера
	local localPlayer = source
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local vehicleid = getPlayerVehicle(localPlayer)

	if logged[playername] == 1 then
		for k,v in pairs(sqlite("SELECT * FROM business_db")) do
			if getElementDimension(localPlayer) == v["world"] and getElementInterior(localPlayer) == interior_business[v["interior"]][1] and enter_business[playername] == 1 then
				x,y,z = v["x"],v["y"],v["z"]
				break
			end
		end

		for k,v in pairs(sqlite("SELECT * FROM house_db")) do
			if getElementDimension(localPlayer) == v["world"] and getElementInterior(localPlayer) == interior_house[v["interior"]][1] and enter_house[playername][1] == 1 then
				x,y,z = v["x"],v["y"],v["z"]
				break
			end
		end

		for id,v in pairs(interior_job) do
			if getElementInterior(localPlayer) == interior_job[id][1] and getElementDimension(localPlayer) == v[10] and enter_job[playername] == 1 then
				x,y,z = v[6],v[7],v[8]
				break
			end
		end

		if armour[playername] ~= 0 then
			destroyElement(armour[playername])
			armour[playername] = 0
		end

		if vehicleid then
			x,y,z = x,y,z+1
		end

		local pass = search_inv_player_2_parameter(localPlayer, 105)
		if pass ~= 0 and getElementData(localPlayer, "player_id") ~= pass then
			inv_player_delet(localPlayer, 105, pass)
		end

		local policetoken = search_inv_player_2_parameter(localPlayer, 10)
		if policetoken ~= 0 and getElementData(localPlayer, "player_id") ~= policetoken then
			inv_player_delet(localPlayer, 10, policetoken)
		end

		local rights = search_inv_player_2_parameter(localPlayer, 2)
		if rights ~= 0 and getElementData(localPlayer, "player_id") ~= rights then
			inv_player_delet(localPlayer, 2, rights)
		end

		local lic_weapon = search_inv_player_2_parameter(localPlayer, 50)
		if lic_weapon ~= 0 and getElementData(localPlayer, "player_id") ~= lic_weapon then
			inv_player_delet(localPlayer, 50, lic_weapon)
		end

		local heal = getElementHealth( localPlayer )
		sqlite( "UPDATE account SET heal = '"..heal.."', x = '"..x.."', y = '"..y.."', z = '"..z.."', arrest = '"..arrest[playername].."', crimes = '"..crimes[playername].."', alcohol = '"..alcohol[playername].."', satiety = '"..satiety[playername].."', hygiene = '"..hygiene[playername].."', sleep = '"..sleep[playername].."', drugs = '"..drugs[playername].."' WHERE name = '"..playername.."'")

		exit_car_fun(localPlayer)
		job_0( playername )
		car_theft_fun(playername)
		robbery_kill( playername )

		logged[playername] = 0
	else
		
	end
end
addEventHandler ( "onPlayerQuit", root, quitPlayer )

function player_Spawn (localPlayer)--спавн игрока
	if isElement ( localPlayer ) then
		local playername = getPlayerName ( localPlayer )
		local randomize = random(1,3)

		if logged[playername] == 1 then
			local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )

			spawnPlayer(localPlayer, hospital_spawn[randomize][1], hospital_spawn[randomize][2], hospital_spawn[randomize][3], 0, result[1]["skin"])

			setElementHealth( localPlayer, 100 )
		end
	end
end

addEventHandler( "onPlayerWasted", root,--смерть игрока
function(ammo, attacker, weapon, bodypart)
	local localPlayer = source
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local playername_a = nil
	local reason = weapon
	local cash = 100
	local time = getRealTime()
	local hour = time["hour"]
	local minute = time["minute"]
	local second = time["second"]

	if time["hour"] < 10 then
		hour = "0"..hour
	end

	if time["minute"] < 10 then
		minute = "0"..minute
	end

	if time["second"] < 10 then
		second = "0"..second
	end

	for k,v in pairs(deathReasons) do
		if k == reason then
			reason = v
		end
	end

	if tonumber(reason) then
		reason = getWeaponNameFromID(reason)
	end

	if attacker then
		if getElementType ( attacker ) == "player" then
			playername_a = getPlayerName ( attacker )

			if playername_a ~= playername then
				if search_inv_player_2_parameter(attacker, 10) == 0 then
					addcrimes(attacker, get("zakon_kill_crimes"))
				else
					if crimes[playername] ~= 0 then
						arrest[playername] = 1

						sendMessage(attacker, "Вы получили премию "..(cash*(crimes[playername])).."$", color_mes.green )

						inv_server_load( attacker, "player", 0, 1, array_player_2[playername_a][1]+(cash*(crimes[playername])), playername_a )
					else
						addcrimes(attacker, get("zakon_kill_crimes"))
					end
				end

				if(point_guns_zone[1] == 1 and search_inv_player_2_parameter(localPlayer, 85) ~= 0 and search_inv_player_2_parameter(attacker, 85) ~= 0) then
				
					for k,v in pairs(guns_zone) do
						if(isInsideRadarArea(v[1], x,y) and k == point_guns_zone[2]) then
						
							if(search_inv_player_2_parameter(localPlayer, 85) == point_guns_zone[5] and search_inv_player_2_parameter(attacker, 85) ~= point_guns_zone[5]) then
							
								points_add_in_gz(attacker, 2)
							end
						end
					end
				end
			end

		elseif getElementType ( attacker ) == "vehicle" then
			for i,player_id in pairs(getElementsByType("player")) do
				local vehicleid = getPlayerVehicle(player_id)

				if attacker == vehicleid then
					playername_a = getPlayerName ( player_id )

					if playername_a ~= playername then
						if search_inv_player_2_parameter(player_id, 10) == 0 then
							addcrimes(player_id, get("zakon_kill_crimes"))
						else
							if crimes[playername] ~= 0 then
								arrest[playername] = 1

								sendMessage(player_id, "Вы получили премию "..(cash*(crimes[playername])).."$", color_mes.green )

								inv_server_load( player_id, "player", 0, 1, array_player_2[playername_a][1]+(cash*(crimes[playername])), playername_a )
							else
								addcrimes(player_id, get("zakon_kill_crimes"))
							end
						end
					end

					break
				end
			end
		end
	end

	robbery_kill( playername )
	job_0( playername )
	car_theft_fun(playername)
	
	setTimer( player_Spawn, 5000, 1, localPlayer )

	--[[if not playername_a then
		sendMessage(root, "[НОВОСТИ] "..playername.." умер Причина: "..tostring(reason).." Часть тела: "..tostring(getBodyPartName ( bodypart )), color_mes.green )
	else
		sendMessage(root, "[НОВОСТИ] "..playername_a.." убил "..playername.." Причина: "..tostring(reason).." Часть тела: "..tostring(getBodyPartName ( bodypart )), color_mes.green )
	end]]

	outputConsole("["..hour..":"..minute..":"..second.."] [onPlayerWasted] "..playername.." [ammo - "..tostring(ammo)..", attacker - "..tostring(playername_a)..", reason - "..tostring(reason)..", bodypart - "..tostring(getBodyPartName ( bodypart )).."]")
end)

function frozen_false_fun( localPlayer )
	if isElement ( localPlayer ) then
		if isElementFrozen(localPlayer) then
			setElementFrozen( localPlayer, false )
			sendMessage(localPlayer, "Вы можете двигаться", color_mes.yellow)
		end
	end
end

function playerDamage_text ( attacker, weapon, bodypart, loss )--получение урона
	local localPlayer = source
	local playername = getPlayerName ( localPlayer )
	local reason = weapon

	if attacker then
		if getElementType ( attacker ) == "player" and getPlayerName(attacker) ~= playername then
			triggerClientEvent( attacker, "event_body_hit_sound", localPlayer )

		elseif getElementType ( attacker ) == "vehicle" then
			for i,localPlayer in pairs(getElementsByType("player")) do
				local vehicleid = getPlayerVehicle(localPlayer)

				if attacker == vehicleid then
					triggerClientEvent( localPlayer, "event_body_hit_sound", localPlayer )
					break
				end
			end
		end
	end

	if (reason == 16 or reason == 3) and not isElementFrozen(localPlayer) then--удар дубинкой оглушает игрока на 15 сек
		local playername_attacker = getPlayerName ( attacker )
		setElementFrozen( localPlayer, true )
		setTimer(frozen_false_fun, 15000, 1, localPlayer)--разморозка
		me_chat(localPlayer, playername_attacker.." оглушил(а) "..playername)
	end

	if bodypart == 9 then
		killPed(localPlayer, attacker, weapon, bodypart)
	end
end
addEventHandler ( "onPlayerDamage", root, playerDamage_text )

function nickChangeHandler(oldNick, newNick)
	local localPlayer = source
	local playername = getPlayerName ( localPlayer )

	--kickPlayer( localPlayer, "kick for Change Nick" )
	cancelEvent()
end
addEventHandler("onPlayerChangeNick", root, nickChangeHandler)

function onStealthKill(targetPlayer)
	cancelEvent() -- Aborts the stealth-kill.
end
addEventHandler("onPlayerStealthKill", root, onStealthKill) -- Adds a handler for the stealth kill event.

----------------------------------Регистрация-Авторизация--------------------------------------------
function reg_or_login(localPlayer)
	local playername = getPlayerName ( localPlayer )
	local serial = getPlayerSerial(localPlayer)
	local ip = getPlayerIP(localPlayer)

	local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..playername.."'" )
	if result[1]["COUNT()"] == 0 then

		local result = sqlite( "SELECT COUNT() FROM account WHERE reg_serial = '"..serial.."'" )
		if result[1]["COUNT()"] >= 1 then
			kickPlayer(localPlayer, "Регистрация твинков запрещена")
			return
		end
		
		local result = sqlite( "INSERT INTO account (name, ban, settings, x, y, z, reg_ip, reg_serial, heal, alcohol, satiety, hygiene, sleep, drugs, skin, arrest, crimes, inventory) VALUES ('"..playername.."', '0', '400', '"..spawnX.."', '"..spawnY.."', '"..spawnZ.."', '"..ip.."', '"..serial.."', '"..get("max_heal").."', '0', '100', '100', '100', '0', '26', '0', '0', '0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,')" )

		local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )

		load_inv(playername, "player", result[1]["inventory"])
		inv_player_empty(localPlayer, 1, 500)
		inv_player_empty(localPlayer, 105, getElementData(localPlayer, "player_id"))

		logged[playername] = 1
		alcohol[playername] = result[1]["alcohol"]
		satiety[playername] = result[1]["satiety"]
		hygiene[playername] = result[1]["hygiene"]
		sleep[playername] = result[1]["sleep"]
		drugs[playername] = result[1]["drugs"]

		spawnPlayer(localPlayer, result[1]["x"], result[1]["y"], result[1]["z"], 0, result[1]["skin"], 0, 0)
		setElementHealth( localPlayer, result[1]["heal"] )

		sendMessage(localPlayer, "Вы удачно зарегистрировались!", color_mes.turquoise)

		print("[ACCOUNT REGISTER] "..playername.." [ip - "..ip..", serial - "..serial.."]")

	elseif result[1]["COUNT()"] == 1 then
		local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )

		if result[1]["reg_serial"] ~= serial then
			kickPlayer(localPlayer, "Вы не владелец аккаунта")
			return
		end

		load_inv(playername, "player", result[1]["inventory"])

		if inv_player_delet(localPlayer, 105, search_inv_player_2_parameter(localPlayer, 105)) then
			inv_player_empty(localPlayer, 105, getElementData(localPlayer, "player_id"))
		end

		if inv_player_delet(localPlayer, 10, search_inv_player_2_parameter(localPlayer, 10)) then
			inv_player_empty(localPlayer, 10, getElementData(localPlayer, "player_id"))
		end

		if inv_player_delet(localPlayer, 2, search_inv_player_2_parameter(localPlayer, 2)) then
			inv_player_empty(localPlayer, 2, getElementData(localPlayer, "player_id"))
		end

		if inv_player_delet(localPlayer, 50, search_inv_player_2_parameter(localPlayer, 50)) then
			inv_player_empty(localPlayer, 50, getElementData(localPlayer, "player_id"))
		end

		triggerClientEvent( localPlayer, "event_setFarClipDistance", localPlayer, tonumber(result[1]["settings"]) )
		setElementData(localPlayer, "settings", result[1]["settings"])

		logged[playername] = 1
		arrest[playername] = result[1]["arrest"]
		crimes[playername] = result[1]["crimes"]
		alcohol[playername] = result[1]["alcohol"]
		satiety[playername] = result[1]["satiety"]
		hygiene[playername] = result[1]["hygiene"]
		sleep[playername] = result[1]["sleep"]
		drugs[playername] = result[1]["drugs"]

		spawnPlayer(localPlayer, result[1]["x"], result[1]["y"], result[1]["z"], 0, result[1]["skin"], 0, 0)

		setElementHealth( localPlayer, result[1]["heal"] )

		sendMessage(localPlayer, "Вы удачно зашли!", color_mes.turquoise)
	end

	fadeCamera(localPlayer, true)
	setCameraTarget(localPlayer, localPlayer)
	setPlayerNametagColor_fun( localPlayer )

	sqlite_load(localPlayer, "quest_table")
	sqlite_load(localPlayer, "auc")
	sqlite_load(localPlayer, "cow_farms_table1")
	sqlite_load(localPlayer, "cow_farms_table2")
	sqlite_load(localPlayer, "carparking_table")
	sqlite_load(localPlayer, "business_table")

	if getElementData(localPlayer, "admin_data") ~= 0 then
		sqlite_load(localPlayer, "account_db")
		sqlite_load(localPlayer, "house_db")
		sqlite_load(localPlayer, "business_db")
		sqlite_load(localPlayer, "car_db")
	end
end
addEvent("event_reg_or_login", true)
addEventHandler("event_reg_or_login", root, reg_or_login)

------------------------------------взрыв авто-------------------------------------------
function fixVehicle_fun( vehicleid )
	if isElement(vehicleid) then
		fixVehicle(vehicleid)
		fixVehicle(vehicleid)
		setElementHealth(vehicleid, 300)
		vehicle_sethandling(vehicleid)
	end
end

function explode_car()
	local vehicleid = source
	local plate = getVehiclePlateText ( vehicleid )

	setTimer(fixVehicle_fun, 5000, 1, vehicleid)

	for k,localPlayer in pairs(getElementsByType("player")) do
		if vehicleid == getPlayerVehicle(localPlayer) then
			removePedFromVehicle ( localPlayer )--антибаг
			setElementHealth(localPlayer, 0.0)
		end
	end

	if getElementModel(vehicleid) == 428 then
		for i=0,get("max_inv") do
			local sic2p = search_inv_car_2_parameter(vehicleid, 65)
			inv_car_throw_earth(vehicleid, 65, sic2p)
		end

		for i=0,get("max_inv") do
			local sic2p = search_inv_car_2_parameter(vehicleid, 66)
			inv_car_throw_earth(vehicleid, 66, sic2p)
		end
	end
end
addEventHandler("onVehicleExplode", root, explode_car)

function vehicle_sethandling(vehicleid)
	local plate = getVehiclePlateText(vehicleid)
	local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )

	local a = getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"]
	local v = getOriginalHandling(getElementModel(vehicleid))["maxVelocity"]
	local b = getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"]

	if result[1] then
		a = a + getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"]*(result[1]["stage"]*get("car_stage_coef"))
		v = v + getOriginalHandling(getElementModel(vehicleid))["maxVelocity"]*(result[1]["stage"]*get("car_stage_coef"))
		b = b + getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"]*(result[1]["stage"]*get("car_stage_coef"))
	end

	local hp = getElementHealth(vehicleid)/1000
	a = a * hp
	v = v * hp
	b = b * hp

	setVehicleHandling(vehicleid, "engineAcceleration", a)
	setVehicleHandling(vehicleid, "maxVelocity", v)
	setVehicleHandling(vehicleid, "brakeDeceleration", b)
	--print(plate,a,v,b)
end

function handleVehicleDamage(loss)
	local vehicleid = source
	vehicle_sethandling(vehicleid)
end
addEventHandler("onVehicleDamage", root, handleVehicleDamage)

function detachTrailer(vehicleid)--прицепка прицепа
	local trailer = source
	local plate = getVehiclePlateText ( trailer )
	local localPlayer = getVehicleController ( vehicleid )

	local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
	if result[1]["COUNT()"] == 1 and getElementModel(vehicleid) == 525 and search_inv_player_2_parameter(localPlayer, 10) ~= 0 then
		local x,y,z = getElementPosition(trailer)
		local rx,ry,rz = getElementRotation(trailer)

		if isInsideColShape(car_shtraf_stoyanka, x,y,z) then
			sqlite( "UPDATE car_db SET frozen = '0', x = '"..x.."', y = '"..y.."', z = '"..z.."', rot = '"..rz.."', fuel = '"..fuel[plate].."' WHERE number = '"..plate.."'")
			setElementFrozen(trailer, false)
		end

		sqlite( "UPDATE car_db SET evacuate = '1' WHERE number = '"..plate.."'")
	end
end
addEventHandler("onTrailerAttach", root, detachTrailer)

function reattachTrailer(vehicleid)--отцепка прицепа
	local trailer = source
	local plate = getVehiclePlateText ( trailer )
	local localPlayer = getVehicleController ( vehicleid )

	local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
	if result[1]["COUNT()"] == 1 and getElementModel(vehicleid) == 525 and search_inv_player_2_parameter(localPlayer, 10) ~= 0 then
		local x,y,z = getElementPosition(trailer)
		local rx,ry,rz = getElementRotation(trailer)

		if isInsideColShape(car_shtraf_stoyanka, x,y,z) then
			sqlite( "UPDATE car_db SET frozen = '1', x = '"..x.."', y = '"..y.."', z = '"..z.."', rot = '"..rz.."', fuel = '"..fuel[plate].."' WHERE number = '"..plate.."'")
			setElementFrozen(trailer, true)
		end

		sqlite( "UPDATE car_db SET evacuate = '0' WHERE number = '"..plate.."'")
	end
end
addEventHandler("onTrailerDetach", root, reattachTrailer)

function car_spawn(number)
	local plate = number
	local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )

	if result[1]["taxation"] ~= 0 and result[1]["theft"] == 0 then
		local vehicleid = createVehicle(result[1]["model"], result[1]["x"], result[1]["y"], result[1]["z"], 0, 0, result[1]["rot"], plate)

		setVehicleLocked ( vehicleid, false )

		fuel[plate] = result[1]["fuel"]
		kilometrage[plate] = result[1]["kilometrage"]
		
		if result[1]["tune"] ~= "0" then
			for k,v in pairs(split(result[1]["tune"], ",")) do
				local value = {}
				for k,v in ipairs(split(v, ":")) do
					table.insert(value, tonumber(v))
				end
				
				local obj = createObject(value[1], 0,0,0, 0,0,0)
				attachElements(obj, vehicleid, value[2],value[3],value[4], value[5],value[6],value[7])
				setObjectScale(obj, value[8])
			end
		end

		if result[1]["wheel"] ~= 0 then
			addVehicleUpgrade(vehicleid, result[1]["wheel"])
		end

		if result[1]["hydraulics"] ~= 0 then
			addVehicleUpgrade(vehicleid, result[1]["hydraulics"])
		end

		setElementData(vehicleid, "tune_car", result[1]["tune"])

		local spl = split(result[1]["car_rgb"], ",")
		local spl2 = split(result[1]["wheel_rgb"], ",")
		setVehicleColor( vehicleid, spl[1], spl[2], spl[3], spl2[1], spl2[2], spl2[3], spl[1], spl[2], spl[3], spl[1], spl[2], spl[3] )

		local spl = split(result[1]["headlight_rgb"], ",")
		setVehicleHeadLightColor ( vehicleid, spl[1], spl[2], spl[3] )

		setVehiclePaintjob ( vehicleid, result[1]["paintjob"] )

		setVehicleHandling(vehicleid, "engineAcceleration", getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"]*(result[1]["stage"]*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"])
		setVehicleHandling(vehicleid, "maxVelocity", getOriginalHandling(getElementModel(vehicleid))["maxVelocity"]*(result[1]["stage"]*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["maxVelocity"])
		setVehicleHandling(vehicleid, "brakeDeceleration", getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"]*(result[1]["stage"]*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"])
			
		array_car_1[plate] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		array_car_2[plate] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

		load_inv(plate, "car", result[1]["inventory"])

		carnumber_number = carnumber_number+1
	end
end
addEvent("event_car_spawn", true)
addEventHandler("event_car_spawn", root, car_spawn)

function spawn_carparking( localPlayer, plate )
	local playername = getPlayerName(localPlayer)
	local count = 0
	local result = sqlite( "SELECT COUNT() FROM car_db WHERE taxation = '0' AND number = '"..plate.."'" )

	for k,vehicleid in pairs(getElementsByType("vehicle")) do
		if getVehiclePlateText(vehicleid) == plate then
			count = 1
			break
		end
	end

	if count == 1 or result[1]["COUNT()"] == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Т/с в городе", color_mes.red)
		return
	end

	if search_inv_player(localPlayer, 61, 7) ~= 0 then
		if inv_player_delet(localPlayer, 61, 7) then
			sqlite( "UPDATE car_db SET taxation = '7' WHERE number = '"..plate.."'")
			car_spawn(plate)

			sendMessage(localPlayer, "Вы забрали т/с под номером "..plate, color_mes.yellow)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] У вас нет "..info_png[61][1].." 7 "..info_png[61][2], color_mes.red)
	end
end
addEvent( "event_spawn_carparking", true )
addEventHandler ( "event_spawn_carparking", root, spawn_carparking )

function random_car_number(int1,int2)
	local randomize = random(int1,int2)
	local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..randomize.."'" )

	while true do
		if result[1]["COUNT()"] == 0 then
			return randomize
		else
			randomize = random(int1,int2)
			result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..randomize.."'" )
		end
	end
end

--addCommandHandler ( "buycar",--покупка авто
function buycar ( localPlayer, id )
	local police_car = {596,597,598,599,427,601,490,525,523,528}
	local police_boats = {430}
	local police_helicopters = {497}

	local playername = getPlayerName ( localPlayer )
	local x1,y1,z1 = getElementPosition ( localPlayer )
	local x,y,z,rot = 0,0,0,0

	if logged[playername] == 0 then
		return
	end

	local id = tonumber(id)

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ид т/с]", color_mes.red)
		return
	end

	if id >= 400 and id <= 611 then
		local val1, val2 = 6, random_car_number(1,99999999-getMaxPlayers()-1)

		if isPointInCircle3D(t_s_salon[1][1],t_s_salon[1][2],t_s_salon[1][3], x1,y1,z1, 5) then
			if cash_car[id] == nil then
				sendMessage(localPlayer, "[ОШИБКА] Этот т/с недоступен", color_mes.red)
				return
			end

			for k,v in pairs(police_car) do
				if v == id and search_inv_player_2_parameter(localPlayer, 10) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
					return
				end
			end

			if cash_car[id][2] > search_inv_player_2_parameter(localPlayer, 1) then
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				return
			end

			if inv_player_empty(localPlayer, val1, val2) then
			else
				sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				return
			end

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash_car[id][2], playername )

			sendMessage(localPlayer, "Вы купили транспортное средство за "..cash_car[id][2].."$", color_mes.orange)

			x,y,z,rot = 2120.8515625,-1136.013671875,25.287223815918,0

		elseif isPointInCircle3D(t_s_salon[2][1],t_s_salon[2][2],t_s_salon[2][3], x1,y1,z1, 5) then
			if cash_helicopters[id] == nil then
				sendMessage(localPlayer, "[ОШИБКА] Этот т/с недоступен", color_mes.red)
				return
			end

			for k,v in pairs(police_helicopters) do
				if v == id and search_inv_player_2_parameter(localPlayer, 10) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
					return
				end
			end

			if cash_helicopters[id][2] > search_inv_player_2_parameter(localPlayer, 1) then
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				return
			end

			if inv_player_empty(localPlayer, val1, val2) then
			else
				sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				return
			end

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash_helicopters[id][2], playername )

			sendMessage(localPlayer, "Вы купили транспортное средство за "..cash_helicopters[id][2].."$", color_mes.orange)

			x,y,z,rot = 1582.072265625,1197.61328125,12.73429775238,0

		elseif isPointInCircle3D(t_s_salon[3][1],t_s_salon[3][2],t_s_salon[3][3], x1,y1,z1, 5) then
			if cash_boats[id] == nil then
				sendMessage(localPlayer, "[ОШИБКА] Этот т/с недоступен", color_mes.red)
				return
			end

			for k,v in pairs(police_boats) do
				if v == id and search_inv_player_2_parameter(localPlayer, 10) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
					return
				end
			end

			if cash_boats[id][2] > search_inv_player_2_parameter(localPlayer, 1) then
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				return
			end

			if inv_player_empty(localPlayer, val1, val2) then
			else
				sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				return
			end

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash_boats[id][2], playername )

			sendMessage(localPlayer, "Вы купили транспортное средство за "..cash_boats[id][2].."$", color_mes.orange)

			x,y,z,rot = -2244.6,2408.7,1.8,315
		else
			sendMessage(localPlayer, "[ОШИБКА] Найдите место продажи т/с", color_mes.red)
			return
		end

		local color = {255,255,255}
		local car_rgb_text = color[1]..","..color[2]..","..color[3]

		local color = {255,255,255}
		local headlight_rgb_text = color[1]..","..color[2]..","..color[3]

		local color = {255,255,255}
		local wheel_rgb_text = color[1]..","..color[2]..","..color[3]

		local paintjob_text = 3

		local taxation_start = 5

		sendMessage(localPlayer, "Вы получили "..info_png[val1][1].." "..val2, color_mes.orange)

		sqlite( "INSERT INTO car_db (number, model, taxation, frozen, evacuate, x, y, z, rot, fuel, car_rgb, headlight_rgb, paintjob, tune, stage, kilometrage, wheel, hydraulics, wheel_rgb, theft, inventory) VALUES ('"..val2.."', '"..id.."', '"..taxation_start.."', '0','0', '"..x.."', '"..y.."', '"..z.."', '"..rot.."', '"..get("max_fuel").."', '"..car_rgb_text.."', '"..headlight_rgb_text.."', '"..paintjob_text.."', '0', '0', '0', '0', '0', '"..wheel_rgb_text.."', '0', '107:"..val2..",0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,')" )
	
		car_spawn(tostring(val2))
	else
		sendMessage(localPlayer, "[ОШИБКА] от 400 до 611", color_mes.red)
	end
end
addEvent( "event_buycar", true )
addEventHandler ( "event_buycar", root, buycar )

--------------------------------------вход и выход в авто--------------------------------
function enter_car ( vehicleid, seat, jacked )--евент входа в авто
	local localPlayer = source
	if getElementType ( localPlayer ) == "player" then

		local playername = getPlayerName ( localPlayer )
		local plate = getVehiclePlateText ( vehicleid )

		if isVehicleLocked ( vehicleid ) then
			removePedFromVehicle ( localPlayer )
			return
		end

		if seat == 0 then
			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
				if result[1]["taxation"] <= 0 then
					sendMessage(localPlayer, "[ОШИБКА] Т/с арестован за уклонение от уплаты налогов", color_mes.red)
					setVehicleEngineState(vehicleid, false)
					return
				end
			end

			if search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 and search_inv_player_2_parameter(localPlayer, 2) == getElementData(localPlayer, "player_id") then
				if tonumber(plate) ~= 0 then
					triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "car", plate )
				end

				if fuel[plate] <= 0 then
					sendMessage(localPlayer, "[ОШИБКА] Бак пуст", color_mes.red)
					setVehicleEngineState(vehicleid, false)
					return
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Чтобы завести т/с надо иметь ключ от т/с и права (можно купить в Мэрии)", color_mes.red)
				setVehicleEngineState(vehicleid, false)
			end
		end
	end
end
addEventHandler ( "onPlayerVehicleEnter", root, enter_car )

function exit_car_fun( localPlayer )
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)

	if vehicleid then
		local plate = getVehiclePlateText ( vehicleid )

		if getVehicleOccupant ( vehicleid, 0 ) == localPlayer then
			setVehicleEngineState(vehicleid, false)

			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				local x,y,z = getElementPosition(vehicleid)
				local rx,ry,rz = getElementRotation(vehicleid)

				sqlite( "UPDATE car_db SET x = '"..x.."', y = '"..y.."', z = '"..z.."', rot = '"..rz.."', fuel = '"..fuel[plate].."', kilometrage = '"..kilometrage[plate].."' WHERE number = '"..plate.."'")
			end
		end
	end
end

function exit_car ( vehicleid, seat, jacked )--евент выхода из авто
	local localPlayer = source
	if getElementType ( localPlayer ) == "player" then

		local playername = getPlayerName ( localPlayer )
		local plate = getVehiclePlateText ( vehicleid )

		if seat == 0 then
			setVehicleEngineState(vehicleid, false)

			triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "car", "" )

			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
			if result[1]["COUNT()"] == 1 then
				local x,y,z = getElementPosition(vehicleid)
				local rx,ry,rz = getElementRotation(vehicleid)

				sqlite( "UPDATE car_db SET x = '"..x.."', y = '"..y.."', z = '"..z.."', rot = '"..rz.."', fuel = '"..fuel[plate].."', kilometrage = '"..kilometrage[plate].."' WHERE number = '"..plate.."'")
			end
		end
	end
end
addEventHandler ( "onPlayerVehicleExit", root, exit_car )

function h_down (localPlayer, key, keyState)--вкл выкл сирены
local playername = getPlayerName ( localPlayer )
local vehicleid = getPlayerVehicle(localPlayer)

	if keyState == "down" then
		if vehicleid then
			if not getVehicleSirensOn ( vehicleid ) then
				setVehicleSirensOn ( vehicleid, true )
			else
				setVehicleSirensOn ( vehicleid, false )
			end
		end
	end
end
-----------------------------------------------------------------------------------------

function tab_down (localPlayer, key, keyState)--открытие инв-ря игрока
local playername = getPlayerName ( localPlayer )
local vehicleid = getPlayerVehicle(localPlayer)
local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if keyState == "down" then
		if state_gui_window[playername] == 0 then--гуи окно
			if state_inv_player[playername] == 0 and arrest[playername] == 0 then--инв-рь игрока
				for i=0,get("max_inv") do
					triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "player", i, array_player_1[playername][i+1], array_player_2[playername][i+1] )
				end

				if vehicleid then
					local plate = getVehiclePlateText ( vehicleid )

					if search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 and getVehicleOccupant ( vehicleid, 0 ) == localPlayer and tonumber(plate) ~= 0 then
						for i=0,get("max_inv") do
							triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "car", i, array_car_1[plate][i+1], array_car_2[plate][i+1] )
						end
					end
				end

				if enter_house[playername][1] == 1 then
					for h,v in pairs(sqlite( "SELECT * FROM house_db" )) do
						if getElementDimension(localPlayer) == v["world"] and getElementInterior(localPlayer) == interior_house[v["interior"]][1] then
							local count = 0
							for k,player in pairs(getElementsByType("player")) do
								local playername2 = getPlayerName(player)
								if enter_house[playername2][2] == v["number"] then
									count = 1
									break
								end
							end

							if count == 0 then
								for i=0,get("max_inv") do
									triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "house", i, array_house_1[v["number"]][i+1], array_house_2[v["number"]][i+1] )
								end

								enter_house[playername][2] = v["number"]

								triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "house", v["number"] )
							end
							break
						end
					end
				end

				local sic2p = search_inv_player_2_parameter(localPlayer, 116)
				if search_inv_player(localPlayer, 115, sic2p) ~= 0 then
					for i=0,get("max_inv") do
						triggerClientEvent( localPlayer, "event_inv_load", localPlayer, "box", i, array_box_1[sic2p][i+1], array_box_2[sic2p][i+1] )
					end

					triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "box", sic2p )
				end

				triggerClientEvent( localPlayer, "event_inv_create", localPlayer )
				state_inv_player[playername] = 1
			elseif state_inv_player[playername] == 1 then
				triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
				state_inv_player[playername] = 0
				enter_house[playername][2] = 0
			end
		end
	end
end

function throw_earth_server (localPlayer, value, id3, id1, id2, tabpanel)--выброс предмета
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local vehicleid = getPlayerVehicle(localPlayer)

	if value == "player" then
		for k,v in pairs(down_player_subject) do
			if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) and id1 == v[5] then--получение прибыли за предметы
				inv_player_delet( localPlayer, id1, id2, false, true )
				inv_server_load( localPlayer, value, 0, 1, search_inv_player_2_parameter(localPlayer, 1)+id2, tabpanel )

				sendMessage(localPlayer, "Вы выбросили "..info_png[id1][1].." "..id2.." "..info_png[id1][2], color_mes.yellow)

				return
			end
		end

		for k,v in pairs(anim_player_subject) do
			if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) and id1 == v[5] and not vehicleid and getElementData(localPlayer, "task") == "TASK_SIMPLE_PLAYER_ON_FOOT" then--обработка предметов
				local randomize = random(1,v[7])

				inv_player_delet( localPlayer, id1, id2, true )
				inv_player_empty( localPlayer, v[6], randomize )

				sendMessage(localPlayer, "Вы получили "..info_png[v[6]][1].." "..randomize.." "..info_png[v[6]][2], color_mes.svetlo_zolotoy)

				--предмет для работы
				if id1 == 30 then
					local obj = object_attach(localPlayer, 322, 12, 0,0.03,0.07, 180,0,-90, (v[12]*1000))
					setElementInterior(obj, v[10])
					setElementDimension(obj, v[11])
				elseif id1 == 67 then
					object_attach(localPlayer, 341, 12, 0,0,0, 0,-90,0, (v[12]*1000))
				elseif id1 == 70 then
					object_attach(localPlayer, 326, 12, 0,0,0, 0,-90,0, (v[12]*1000))
				end

				setPedAnimation(localPlayer, v[8], v[9], -1, true, false, false, false)

				setTimer(function ()
					if isElement(localPlayer) then
						setPedAnimation(localPlayer, nil, nil)
					end
				end, (v[12]*1000), 1)

				return
			end
		end
	end

	max_earth = max_earth+1
	earth[max_earth] = {x,y,z,id1,id2}

	setElementData(resourceRoot, "earth_data", earth)

	--[[if enter_house[playername][2] == id2 and id1 == 25 then--когда выбрасываешь ключ в инв-ре исчезают картинки(выкл из-за фичи)
		triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "house", "" )
		enter_house[playername][2] = 0
	end]]

	if id1 == 115 or id1 == 116 then--когда выбрасываешь ключ в инв-ре исчезают картинки
		triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "box", "" )
	end

	if vehicleid then
		local plate = getVehiclePlateText ( vehicleid )

		if getVehicleOccupant ( vehicleid, 0 ) == localPlayer and id2 == tonumber(plate) and id1 == 6 then--когда выбрасываешь ключ в инв-ре исчезают картинки
			triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "car", "" )
		end
	end

	inv_server_load( localPlayer, value, id3, 0, 0, tabpanel )

	me_chat(localPlayer, playername.." выбросил(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])
	--sendMessage(localPlayer, "Вы выбросили "..info_png[id1][1].." "..id2.." "..info_png[id1][2], color_mes.yellow)
end
addEvent( "event_throw_earth_server", true )
addEventHandler ( "event_throw_earth_server", root, throw_earth_server )

function e_down (localPlayer, key, keyState)--подбор предметов с земли
	local x,y,z = getElementPosition(localPlayer)
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	
	if logged[playername] == 0 then
		return
	end

	if keyState == "down" then

		for k,v in pairs(down_car_subject) do
			if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) then
				if vehicleid then
					if getElementModel(vehicleid) ~= v[6] then
						sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в "..getVehicleNameFromModel ( v[6] ).."("..v[6]..")", color_mes.red)
						return
					end
				end

				delet_subject(localPlayer, v[5])
			end
		end

		for k,v in pairs(up_car_subject) do
			if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) then
				if vehicleid then
					if getElementModel(vehicleid) ~= v[6] then
						sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в "..getVehicleNameFromModel ( v[6] ).."("..v[6]..")", color_mes.red)
						return
					end
				end

				give_subject(localPlayer, "car", v[5], random(v[7]/2,v[7]), true)
			end
		end

		for k,v in pairs(up_player_subject) do
			if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) then
				if v[9] ~= 0 then
					if getElementModel(localPlayer) ~= v[9] then
						sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде "..v[9], color_mes.red)
						return
					end
				end

				give_subject(localPlayer, "player", v[5], random(1,v[6]), true)
			end
		end

		for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do
			if isPointInCircle3D(x,y,z, v["x"],v["y"],v["z"], get("delet_subject_radius")) then
				if vehicleid then
					if getElementModel(vehicleid) ~= down_car_subject[1][6] then
						sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в "..getVehicleNameFromModel ( down_car_subject[1][6] ).."("..down_car_subject[1][6]..")", color_mes.red)
						return
					end
				end

				delet_subject(localPlayer, 24)
			end
		end


		for i,v in pairs(earth) do
			local area = isPointInCircle3D( x, y, z, v[1], v[2], v[3], 10 )

			if area then
				local count = false
				for k,v1 in pairs(up_player_subject) do
					if v[4] == v1[5] then
						count = true
						break
					end
				end

				if count and search_inv_player(localPlayer, v[4], search_inv_player_2_parameter(localPlayer, v[4])) >= 1 then
					sendMessage(localPlayer, "[ОШИБКА] Можно переносить только один предмет", color_mes.red)
					return
				end

				if inv_player_empty(localPlayer, v[4], v[5]) then
					
					me_chat(localPlayer, playername.." поднял(а) "..info_png[ v[4] ][1].." "..v[5].." "..info_png[ v[4] ][2])
					--sendMessage(localPlayer, "Вы подняли "..info_png[ v[4] ][1].." "..v[5].." "..info_png[ v[4] ][2], color_mes.svetlo_zolotoy)

					earth[i] = nil

					setElementData(resourceRoot, "earth_data", earth)
				else
					sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
				end

				return
			end
		end
	end
end

function x_down (localPlayer, key, keyState)
local playername = getPlayerName ( localPlayer )
local x,y,z = getElementPosition(localPlayer)
local vehicleid = getPlayerVehicle(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if keyState == "down" then
		if state_inv_player[playername] == 0 then--инв-рь игрока
			if state_gui_window[playername] == 0 then

				for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do--бизнесы
					if getElementDimension(localPlayer) == v["world"] and v["type"] == interior_business[1][2] and enter_business[playername] == 1 then--оружие
						triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, v["number"], 1 )
						state_gui_window[playername] = 1
						return

					elseif getElementDimension(localPlayer) == v["world"] and v["type"] == interior_business[2][2] and enter_business[playername] == 1 then--одежда
						triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, v["number"], 2 )
						state_gui_window[playername] = 1
						return

					elseif getElementDimension(localPlayer) == v["world"] and v["type"] == interior_business[3][2] and enter_business[playername] == 1 then--24/7
						triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, v["number"], 3 )
						state_gui_window[playername] = 1
						return

					elseif isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) and v["type"] == interior_business[4][2] then--заправка

						if v["taxation"] <= 0 then
							sendMessage(localPlayer, "[ОШИБКА] Бизнес арестован за уклонение от уплаты налогов", color_mes.red)
							return
						end

						triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, v["number"], 4 )
						state_gui_window[playername] = 1
						return

					elseif isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) and v["type"] == interior_business[5][2] then--тюнинг

						if v["taxation"] <= 0 then
							sendMessage(localPlayer, "[ОШИБКА] Бизнес арестован за уклонение от уплаты налогов", color_mes.red)
							return
						end

						triggerClientEvent( localPlayer, "event_tune_create", localPlayer, v["number"] )
						state_gui_window[playername] = 1
						return
					end
				end


				if enter_job[playername] == 1 then--здания
					local police_station = {2,3,4,15,16,17,18}
					for k,v in pairs(police_station) do
						if interior_job[v][1] == getElementInterior(localPlayer) and interior_job[v][10] == getElementDimension(localPlayer) then
							if search_inv_player_2_parameter(localPlayer, 10) == 0 then
								sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
								return
							end

							triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, -1, "pd" )
							state_gui_window[playername] = 1
							return
						end
					end

					local mayoralty = {5,7,8}
					for k,v in pairs(mayoralty) do				
						if interior_job[v][1] == getElementInterior(localPlayer) and interior_job[v][10] == getElementDimension(localPlayer) then
							triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, -1, "mer" )
							state_gui_window[playername] = 1
							return
						end
					end

					local black_auc = {22}
					for k,v in pairs(black_auc) do
						if interior_job[v][1] == getElementInterior(localPlayer) and interior_job[v][10] == getElementDimension(localPlayer) then
							if crimes[playername] < get("crimes_giuseppe") then
								sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..get("crimes_giuseppe").." преступлений", color_mes.red)
								return
							end

							triggerClientEvent( localPlayer, "event_shop_menu", localPlayer, -1, "giuseppe" )
							state_gui_window[playername] = 1
							return
						end
					end
				end

				if isPointInCircle3D(t_s_salon[1][1],t_s_salon[1][2],t_s_salon[1][3], x,y,z, 5) then
					triggerClientEvent( localPlayer, "event_avto_bikes_menu", localPlayer )
					state_gui_window[playername] = 1
					return
				elseif isPointInCircle3D(t_s_salon[2][1],t_s_salon[2][2],t_s_salon[2][3], x,y,z, 5) then
					triggerClientEvent( localPlayer, "event_helicopters_menu", localPlayer )
					state_gui_window[playername] = 1
					return
				elseif isPointInCircle3D(t_s_salon[3][1],t_s_salon[3][2],t_s_salon[3][3], x,y,z, 5) then
					triggerClientEvent( localPlayer, "event_boats_menu", localPlayer )
					state_gui_window[playername] = 1
					return
				end

			else
				triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )
				state_gui_window[playername] = 0
			end
		end
	end
end

function left_alt_down (localPlayer, key, keyState)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local vehicleid = getPlayerVehicle(localPlayer)

	if logged[playername] == 0 or getElementData(localPlayer, "is_chat_open") == 1 then
		return
	end

	if keyState == "down" then

		for id2,v in pairs(sqlite( "SELECT * FROM house_db" )) do--вход в дома
			if not vehicleid then
				local id = v["interior"]
				local house_door = v["door"]

				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) then
					if house_door == 0 then
						sendMessage(localPlayer, "[ОШИБКА] Дверь закрыта", color_mes.red)
						return
					end

					if v["taxation"] <= 0 then
						sendMessage(localPlayer, "[ОШИБКА] Дом арестован за уклонение от уплаты налогов", color_mes.red)
						return
					end

					enter_house[playername][1] = 1
					setElementDimension(localPlayer, v["world"])
					setElementInterior(localPlayer, interior_house[id][1], interior_house[id][3], interior_house[id][4], interior_house[id][5])
					return

				elseif getElementDimension(localPlayer) == v["world"] and getElementInterior(localPlayer) == interior_house[id][1] and enter_house[playername][1] == 1 then
					if house_door == 0 then
						sendMessage(localPlayer, "[ОШИБКА] Дверь закрыта", color_mes.red)
						return
					end

					enter_house[playername][1] = 0
					setElementDimension(localPlayer, 0)
					setElementInterior(localPlayer, 0, v["x"],v["y"],v["z"])

					if search_inv_player(localPlayer, 25, v["number"]) ~= 0 then
						triggerClientEvent( localPlayer, "event_tab_load", localPlayer, "house", "" )
					end
					return
				end
			end
		end


		for id2,v in pairs(sqlite( "SELECT * FROM business_db" )) do--вход в бизнесы
			if not vehicleid then
				local id = v["interior"]

				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) then
					if id == 5 or id == 4 then
						return
					end

					if v["taxation"] <= 0 then
						sendMessage(localPlayer, "[ОШИБКА] Бизнес арестован за уклонение от уплаты налогов", color_mes.red)
						return
					end
					
					triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )

					state_gui_window[playername] = 0
					enter_business[playername] = 1
					setElementDimension(localPlayer, v["world"])
					setElementInterior(localPlayer, interior_business[id][1], interior_business[id][3], interior_business[id][4], interior_business[id][5])
					return

				elseif getElementDimension(localPlayer) == v["world"] and getElementInterior(localPlayer) == interior_business[id][1] and enter_business[playername] == 1 then

					triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )

					state_gui_window[playername] = 0
					enter_business[playername] = 0
					setElementDimension(localPlayer, 0)
					setElementInterior(localPlayer, 0, v["x"],v["y"],v["z"])
					return
				end
			end
		end


		for id,v in pairs(interior_job) do--вход в здания
			if not vehicleid then
				if isPointInCircle3D(v[6],v[7],v[8], x,y,z, 5) and getElementInterior(localPlayer) == 0 and getElementDimension(localPlayer) == 0 then
					if id == 9 or id == 10 or id == 11 or id == 12 then
						if inv_player_empty(localPlayer, 6, 0) then
						else
							sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
							return
						end
					end

					triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )

					state_gui_window[playername] = 0
					enter_job[playername] = 1
					setElementDimension(localPlayer, v[10])
					setElementInterior(localPlayer, interior_job[id][1], interior_job[id][3], interior_job[id][4], interior_job[id][5])
					return

				elseif getElementInterior(localPlayer) == interior_job[id][1] and getElementDimension(localPlayer) == v[10] and enter_job[playername] == 1 then
					if id == 9 or id == 10 or id == 11 or id == 12 then
						inv_player_delet(localPlayer, 6, 0, true)
					end

					triggerClientEvent( localPlayer, "event_gui_delet", localPlayer )

					state_gui_window[playername] = 0
					enter_job[playername] = 0
					setElementDimension(localPlayer, 0)
					setElementInterior(localPlayer, 0, v[6],v[7],v[8])
					return
				end
			end
		end

	end
end

function give_subject( localPlayer, value, id1, id2, load_value )--выдача предметов игроку или авто
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local vehicleid = getPlayerVehicle(localPlayer)
	local count2 = 0

	if value == "player" then

		if search_inv_player(localPlayer, id1, search_inv_player_2_parameter(localPlayer, id1)) >= 1 then
			sendMessage(localPlayer, "[ОШИБКА] Можно переносить только один предмет", color_mes.red)
			return
		end

		if inv_player_empty(localPlayer, id1, id2) then

			sendMessage(localPlayer, "Вы получили "..info_png[id1][1].." "..id2.." "..info_png[id1][2], color_mes.svetlo_zolotoy)

			random_sub (localPlayer, id1)
		else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
		end

	elseif value == "car" then--для работ по перевозке ящиков

		if vehicleid then
			count2 = amount_inv_car_1_parameter(vehicleid, 0)

			if getVehicleOccupant ( vehicleid, 0 ) ~= localPlayer then
				return

			elseif count2 == 0 then
				sendMessage(localPlayer, "[ОШИБКА] Багажник заполнен", color_mes.red)
				return

			elseif id1 == 65 then
				if search_inv_player(localPlayer, 64, 3) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не инкассатор", color_mes.red)
					return
				end
			elseif id1 == 24 or id1 == 73 then
				if search_inv_player(localPlayer, 64, 7) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не дальнобойщик", color_mes.red)
					return
				end
			elseif id1 == 66 then
				if search_inv_player(localPlayer, 64, 8) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не перевозчик оружия", color_mes.red)
					return
				end
			elseif id1 == 75 then
				if search_inv_player(localPlayer, 64, 2) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не водитель мусоровоза", color_mes.red)
					return
				end
			elseif id1 == 78 then
				if search_inv_player(localPlayer, 64, 4) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не рыболов", color_mes.red)
					return
				end
			elseif id1 == 88 then
				if search_inv_player(localPlayer, 64, 7) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не дальнобойщик", color_mes.red)
					return
				elseif search_inv_player(localPlayer, 87, search_inv_player_2_parameter(localPlayer, 87)) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не работаете на скотобойне", color_mes.red)
					return
				elseif not cow_farms(localPlayer, "load", count2, 0) then
					return
				end
			elseif id1 == 89 then
				if search_inv_player(localPlayer, 64, 7) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не дальнобойщик", color_mes.red)
					return
				elseif search_inv_player(localPlayer, 87, search_inv_player_2_parameter(localPlayer, 87)) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не работаете на скотобойне", color_mes.red)
					return
				end
			end

			inv_car_empty(localPlayer, id1, id2, load_value)

			sendMessage(localPlayer, "Вы загрузили в т/с "..info_png[id1][1].." за "..id2.."$", color_mes.svetlo_zolotoy)
				
			if id1 == 24 then
				sendMessage(localPlayer, "[TIPS] Езжайте в порт или в любой бизнес, чтобы разгрузиться", color_mes.color_tips)
			elseif id1 == 73 then
				sendMessage(localPlayer, "[TIPS] Езжайте в порт, чтобы разгрузиться", color_mes.color_tips)
			elseif id1 == 88 then
				sendMessage(localPlayer, "[TIPS] Езжайте на мясокомбинат, чтобы разгрузиться", color_mes.color_tips)
			elseif id1 == 89 then
				sendMessage(localPlayer, "[TIPS] Езжайте на скотобойню, чтобы разгрузиться", color_mes.color_tips)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
		end
	end

end

function delet_subject(localPlayer, id)--удаление предметов из авто, для работ по перевозке ящиков
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	local x,y,z = getElementPosition(localPlayer)
	local money = 0
		
	if vehicleid then
		if getVehicleOccupant ( vehicleid, 0 ) ~= localPlayer then
			return
		end

		local sic2p = search_inv_car_2_parameter(vehicleid, id)
		local count = search_inv_car(vehicleid, id, sic2p)

		if count ~= 0 then

			for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do
				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("delet_subject_radius")) then

					if id ~= 24 then
						sendMessage(localPlayer, "[ОШИБКА] Нужен только "..info_png[24][1], color_mes.red)
						return
					end

					if v["warehouse"] >= get("max_business") then
						sendMessage(localPlayer, "[ОШИБКА] Склад полон", color_mes.red)
						return
					end

					money = count*sic2p

					if v["money"] < money then
						sendMessage(localPlayer, "[ОШИБКА] Недостаточно средств на балансе бизнеса", color_mes.red)
						return
					end

					inv_car_delet(localPlayer, id, sic2p, true, true, true)

					sqlite( "UPDATE business_db SET warehouse = warehouse + '"..count.."', money = money - '"..money.."' WHERE number = '"..v["number"].."'")

					inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money, playername )

					sendMessage(localPlayer, "Вы разгрузили из т/с "..info_png[id][1].." "..count.." шт за "..money.."$", color_mes.green)
					return
				end
			end

			for k,v in pairs(down_car_subject) do
				if isPointInCircle3D(x,y,z, v[1],v[2],v[3], v[4]) then--места разгрузки
					if not cow_farms(localPlayer, "unload", count, sic2p) and not cow_farms(localPlayer, "unload_prod", count, sic2p) then

						inv_car_delet(localPlayer, id, sic2p, true, true, true)

						money = count*sic2p

						inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money, playername )

						sendMessage(localPlayer, "Вы разгрузили из т/с "..info_png[id][1].." "..count.." шт за "..money.."$", color_mes.green)
					end
					return
				end
			end
		else
			--sendMessage(localPlayer, "[ОШИБКА] Багажник пуст", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
	end
end

function inv_server_load (localPlayer, value, id3, id1, id2, tabpanel)--изменение(сохранение) инв-ря на сервере
	local playername = getPlayerName(localPlayer)
	local plate = tabpanel
	local h = tabpanel
	local b = tabpanel

	if value == "player" then
		array_player_1[playername][id3+1] = id1
		array_player_2[playername][id3+1] = id2

		if id3+1 < get("max_inv")+2 then
			setPlayerNametagColor_fun( localPlayer )
			sqlite_load(localPlayer, "cow_farms_table1")
			sqlite_load(localPlayer, "business_table")
			
			triggerClientEvent( localPlayer, "event_inv_load", localPlayer, value, id3, array_player_1[playername][id3+1], array_player_2[playername][id3+1] )

			if state_inv_player[playername] == 1 then
				triggerClientEvent( localPlayer, "event_change_image", localPlayer, value, id3, array_player_1[playername][id3+1] )
			end
		end

		sqlite( "UPDATE account SET inventory = '"..save_inv(playername, "player").."' WHERE name = '"..playername.."'")

	elseif value == "car" then
		array_car_1[plate][id3+1] = id1
		array_car_2[plate][id3+1] = id2

		triggerClientEvent( localPlayer, "event_inv_load", localPlayer, value, id3, array_car_1[plate][id3+1], array_car_2[plate][id3+1] )

		if state_inv_player[playername] == 1 then
			triggerClientEvent( localPlayer, "event_change_image", localPlayer, value, id3, array_car_1[plate][id3+1] )
		end

		local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
		if result[1]["COUNT()"] == 1 then
			sqlite( "UPDATE car_db SET inventory = '"..save_inv(plate, "car").."' WHERE number = '"..plate.."'")
		end
		
	elseif value == "house" then
		array_house_1[h][id3+1] = id1
		array_house_2[h][id3+1] = id2

		triggerClientEvent( localPlayer, "event_inv_load", localPlayer, value, id3, array_house_1[h][id3+1], array_house_2[h][id3+1] )
		
		if state_inv_player[playername] == 1 then
			triggerClientEvent( localPlayer, "event_change_image", localPlayer, value, id3, array_house_1[h][id3+1] )
		end

		sqlite( "UPDATE house_db SET inventory = '"..save_inv(h, "house").."' WHERE number = '"..h.."'")

	elseif value == "box" then
		array_box_1[b][id3+1] = id1
		array_box_2[b][id3+1] = id2

		triggerClientEvent( localPlayer, "event_inv_load", localPlayer, value, id3, array_box_1[b][id3+1], array_box_2[b][id3+1] )
		
		if state_inv_player[playername] == 1 then
			triggerClientEvent( localPlayer, "event_change_image", localPlayer, value, id3, array_box_1[b][id3+1] )
		end

		sqlite( "UPDATE box_db SET inventory = '"..save_inv(b, "box").."' WHERE number = '"..b.."'")
	end
end
addEvent( "event_inv_server_load", true )
addEventHandler ( "event_inv_server_load", root, inv_server_load )

function use_inv (localPlayer, value, id3, id_1, id_2 )--использование предметов
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)
	local x,y,z = getElementPosition(localPlayer)
	local id1, id2 = id_1, id_2

	if value == "player" then

-----------------------------------------------------нужды-------------------------------------------------------------
		if id1 == 3 or id1 == 7 or id1 == 8 then--сигареты
			local satiety_plus = 5

			if getElementHealth(localPlayer) == get("max_heal") then
				sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
				return
			end

			id2 = id2 - 1

			if id1 == 3 then
				local hp = get("max_heal")*0.05
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

			elseif id1 == 7 then
				local hp = get("max_heal")*0.10
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

			elseif id1 == 8 then
				local hp = get("max_heal")*0.15
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)
			end

			if satiety[playername]+satiety_plus <= max_satiety then
				satiety[playername] = satiety[playername]+satiety_plus
				sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
			end

			object_attach(localPlayer, 1485, 12, -0.1,0,0.04, 0,0,10, 3500)

			if vehicleid then
				setPedAnimation(localPlayer, "ped", "smoke_in_car", -1, false, false, false, false)
			else
				setPedAnimation(localPlayer, "smoking", "m_smk_drag", -1, false, false, false, false)
			end

			me_chat(localPlayer, playername.." выкурил(а) сигарету")

		elseif id1 == 4 then--аптечка
			if getElementHealth(localPlayer) == get("max_heal") then
				sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
				return
			end

			id2 = id2 - 1

			setElementHealth(localPlayer, get("max_heal"))
			sendMessage(localPlayer, "+"..get("max_heal").." хп", color_mes.yellow)

			me_chat(localPlayer, playername.." использовал(а) аптечку")

		elseif id1 == 20 then--нарко
			local satiety_plus = 20
			local sleep_plus = 20
			local drugs_plus = 1

			if getElementHealth(localPlayer) == get("max_heal") then
				sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
				return
			elseif drugs[playername]+drugs_plus > max_drugs then
				sendMessage(localPlayer, "[ОШИБКА] У вас сильная наркозависимость", color_mes.red)
				return
			end

			id2 = id2 - 1

			local hp = get("max_heal")*0.50
			setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
			sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

			drugs[playername] = drugs[playername]+drugs_plus
			sendMessage(localPlayer, "+"..drugs_plus.." ед. наркозависимости", color_mes.yellow)

			if satiety[playername]+satiety_plus <= max_satiety then
				satiety[playername] = satiety[playername]+satiety_plus
				sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
			end

			if sleep[playername]+sleep_plus <= max_sleep then
				sleep[playername] = sleep[playername]+sleep_plus
				sendMessage(localPlayer, "+"..sleep_plus.." ед. сна", color_mes.yellow)
			end

			object_attach(localPlayer, 1485, 12, -0.1,0,0.04, 0,0,10, 3500)

			if vehicleid then
				setPedAnimation(localPlayer, "ped", "smoke_in_car", -1, false, false, false, false)
			else
				setPedAnimation(localPlayer, "smoking", "m_smk_drag", -1, false, false, false, false)
			end

			me_chat(localPlayer, playername.." употребил(а) наркотики")

		elseif id1 == 21 or id1 == 22 then--пиво
			local alcohol_plus = 10
			local hygiene_minys = 5

			if getElementHealth(localPlayer) == get("max_heal") then
				sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
				return
			elseif alcohol[playername]+alcohol_plus > max_alcohol then
				sendMessage(localPlayer, "[ОШИБКА] Вы сильно пьяны", color_mes.red)
				return
			end

			id2 = id2 - 1

			if id1 == 21 then
				local satiety_plus = 10
				local hp = get("max_heal")*0.20
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

				if satiety[playername]+satiety_plus <= max_satiety then
					satiety[playername] = satiety[playername]+satiety_plus
					sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				end

			elseif id1 == 22 then
				local satiety_plus = 5
				local hp = get("max_heal")*0.25
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

				if satiety[playername]+satiety_plus <= max_satiety then
					satiety[playername] = satiety[playername]+satiety_plus
					sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				end
			end

			alcohol[playername] = alcohol[playername]+alcohol_plus
			sendMessage(localPlayer, "+"..(alcohol_plus/100).." промилле", color_mes.yellow)

			if hygiene[playername]-hygiene_minys >= 0 then
				hygiene[playername] = hygiene[playername]-hygiene_minys
				sendMessage(localPlayer, "-"..hygiene_minys.." ед. чистоплотности", color_mes.yellow)
			end

			object_attach(localPlayer, 1484, 11, 0.1,-0.02,0.13, 0,130,0, 2000)
			setPedAnimation(localPlayer, "vending", "vend_drink2_p", -1, false, false, false, false)

			me_chat(localPlayer, playername.." выпил(а) "..info_png[id1][1])

		elseif id1 == 72 or id1 == 103 then--виски,водка

			if id1 == 72 then
				local alcohol_plus = 100
				local hygiene_minys = 10

				if getElementHealth(localPlayer) == get("max_heal") then
					sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
					return
				elseif alcohol[playername]+alcohol_plus > max_alcohol then
					sendMessage(localPlayer, "[ОШИБКА] Вы сильно пьяны", color_mes.red)
					return
				end

				id2 = id2 - 1

				local satiety_plus = 10
				local hp = get("max_heal")*0.50
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

				if satiety[playername]+satiety_plus <= max_satiety then
					satiety[playername] = satiety[playername]+satiety_plus
					sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				end

				alcohol[playername] = alcohol[playername]+alcohol_plus
				sendMessage(localPlayer, "+"..(alcohol_plus/100).." промилле", color_mes.yellow)

				if hygiene[playername]-hygiene_minys >= 0 then
					hygiene[playername] = hygiene[playername]-hygiene_minys
					sendMessage(localPlayer, "-"..hygiene_minys.." ед. чистоплотности", color_mes.yellow)
				end

				object_attach(localPlayer, 1484, 11, 0.1,-0.02,0.13, 0,130,0, 2000)
				setPedAnimation(localPlayer, "vending", "vend_drink2_p", -1, false, false, false, false)

				me_chat(localPlayer, playername.." выпил(а) "..info_png[id1][1])

			elseif id1 == 103 then
				local alcohol_plus = 50
				local hygiene_minys = 10

				if getElementHealth(localPlayer) == get("max_heal") then
					sendMessage(localPlayer, "[ОШИБКА] У вас полное здоровье", color_mes.red)
					return
				elseif alcohol[playername]+alcohol_plus > max_alcohol then
					sendMessage(localPlayer, "[ОШИБКА] Вы сильно пьяны", color_mes.red)
					return
				end

				id2 = id2 - 1

				local satiety_plus = 10
				local hp = get("max_heal")*0.40
				setElementHealth(localPlayer, getElementHealth(localPlayer)+hp)
				sendMessage(localPlayer, "+"..hp.." хп", color_mes.yellow)

				if satiety[playername]+satiety_plus <= max_satiety then
					satiety[playername] = satiety[playername]+satiety_plus
					sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				end

				alcohol[playername] = alcohol[playername]+alcohol_plus
				sendMessage(localPlayer, "+"..(alcohol_plus/100).." промилле", color_mes.yellow)

				if hygiene[playername]-hygiene_minys >= 0 then
					hygiene[playername] = hygiene[playername]-hygiene_minys
					sendMessage(localPlayer, "-"..hygiene_minys.." ед. чистоплотности", color_mes.yellow)
				end

				object_attach(localPlayer, 1484, 11, 0.1,-0.02,0.13, 0,130,0, 2000)
				setPedAnimation(localPlayer, "vending", "vend_drink2_p", -1, false, false, false, false)

				me_chat(localPlayer, playername.." выпил(а) "..info_png[id1][1])
			end

		elseif id1 == 53 or id1 == 54 then--бургер, пицца
			id2 = id2 - 1

			if id1 == 53 then
				local satiety_plus = 50

				if satiety[playername]+satiety_plus > max_satiety then
					sendMessage(localPlayer, "[ОШИБКА] Вы не голодны", color_mes.red)
					return
				end

				satiety[playername] = satiety[playername]+satiety_plus
				sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				me_chat(localPlayer, playername.." съел(а) "..info_png[id1][1])

				object_attach(localPlayer, 2703, 12, 0.02,0.05,0.04, 0,130,0, 5000)
				setPedAnimation(localPlayer, "food", "eat_burger", -1, false, false, false, false)

			elseif id1 == 54 then
				local satiety_plus = 25

				if satiety[playername]+satiety_plus > max_satiety then
					sendMessage(localPlayer, "[ОШИБКА] Вы не голодны", color_mes.red)
					return
				end

				satiety[playername] = satiety[playername]+satiety_plus
				sendMessage(localPlayer, "+"..satiety_plus.." ед. сытости", color_mes.yellow)
				me_chat(localPlayer, playername.." съел(а) "..info_png[id1][1])

				object_attach(localPlayer, 2702, 12, 0,0.1,0.05, 0,270,0, 5000)
				setPedAnimation(localPlayer, "food", "eat_pizza", -1, false, false, false, false)
			end

		elseif id1 == 55 or id1 == 56 then--мыло, пижама

			if id1 == 55 then
				local sleep_hygiene_plus = 50

				if hygiene[playername]+sleep_hygiene_plus > max_hygiene then
					sendMessage(localPlayer, "[ОШИБКА] Вы чисты", color_mes.red)
					return
				end

				if enter_house[playername][1] == 1 then
					hygiene[playername] = hygiene[playername]+sleep_hygiene_plus
					sendMessage(localPlayer, "+"..sleep_hygiene_plus.." ед. чистоплотности", color_mes.yellow)
					me_chat(localPlayer, playername.." помылся(ась)")
					id2 = id2 - 1

					setPedAnimation(localPlayer, "int_house", "wash_up", -1, false, false, false, false)

				elseif (enter_job[playername] == 1 and (interior_job[19][1] == getElementInterior(localPlayer) and interior_job[19][10] == getElementDimension(localPlayer) or interior_job[20][1] == getElementInterior(localPlayer) and interior_job[20][10] == getElementDimension(localPlayer) or interior_job[21][1] == getElementInterior(localPlayer) and interior_job[21][10] == getElementDimension(localPlayer) or interior_job[24][1] == getElementInterior(localPlayer) and interior_job[24][10] == getElementDimension(localPlayer)) ) then
				
					if (player_hotel(localPlayer, 55)) then
					
						id2 = id2 - 1
					else
						return
					end
				
				else 
				
					sendMessage(localPlayer, "[ОШИБКА] Вы не в доме и не в отеле", color_mes.red)
					return
				end

			elseif id1 == 56 then
				local sleep_hygiene_plus = 50

				if sleep[playername]+sleep_hygiene_plus > max_sleep then
					sendMessage(localPlayer, "[ОШИБКА] Вы бодры", color_mes.red)
					return
				end

				if enter_house[playername][1] == 1 then
					sleep[playername] = sleep[playername]+sleep_hygiene_plus
					sendMessage(localPlayer, "+"..sleep_hygiene_plus.." ед. сна", color_mes.yellow)
					me_chat(localPlayer, playername.." вздремнул(а)")
					id2 = id2 - 1

				elseif (enter_job[playername] == 1 and (interior_job[19][1] == getElementInterior(localPlayer) and interior_job[19][10] == getElementDimension(localPlayer) or interior_job[20][1] == getElementInterior(localPlayer) and interior_job[20][10] == getElementDimension(localPlayer) or interior_job[21][1] == getElementInterior(localPlayer) and interior_job[21][10] == getElementDimension(localPlayer) or interior_job[24][1] == getElementInterior(localPlayer) and interior_job[24][10] == getElementDimension(localPlayer)) ) then
				
					if (player_hotel(localPlayer, 56)) then
					
						id2 = id2 - 1
					else
						return
					end
				
				else 
				
					sendMessage(localPlayer, "[ОШИБКА] Вы не в доме и не в отеле", color_mes.red)
					return
				end
			end

		elseif id1 == 42 then--лекарство от наркозависимости
			id2 = id2 - 1

			local drugs_minys = 10

			if drugs[playername]-drugs_minys < 0 then
				sendMessage(localPlayer, "[ОШИБКА] У вас нет наркозависимости", color_mes.red)
				return
			end

			drugs[playername] = drugs[playername]-drugs_minys
			sendMessage(localPlayer, "-"..drugs_minys.." ед. наркозависимости", color_mes.yellow)
			me_chat(localPlayer, playername.." выпил(а) "..info_png[id1][1])

		elseif id1 == 76 then--антипохмелин
			id2 = id2 - 1

			local alcohol_minys = 50

			if alcohol[playername]-alcohol_minys < 0 then
				sendMessage(localPlayer, "[ОШИБКА] Вы не пьяны", color_mes.red)
				return
			end

			alcohol[playername] = alcohol[playername]-alcohol_minys
			sendMessage(localPlayer, "-"..(alcohol_minys/100).." промилле", color_mes.yellow)
			me_chat(localPlayer, playername.." выпил(а) "..info_png[id1][1])
-----------------------------------------------------------------------------------------------------------------------

		elseif id1 == 5 then--канистра
			if vehicleid then
				local plate = getVehiclePlateText ( vehicleid )

				if getSpeed(vehicleid) < 5 then
					if fuel[plate]+id2 <= get("max_fuel") then

						fuel[plate] = fuel[plate]+id2
						me_chat(localPlayer, playername.." заправил(а) т/с из канистры")
						id2 = 0

						sqlite( "UPDATE car_db SET fuel = '"..fuel[plate].."' WHERE number = '"..plate.."'")

						local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
						if result[1]["COUNT()"] == 1 then
							local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
							if result[1]["taxation"] ~= 0 and search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 and search_inv_player_2_parameter(localPlayer, 2) == getElementData(localPlayer, "player_id") and getVehicleOccupant(vehicleid, 0) == localPlayer then
								setVehicleEngineState(vehicleid, true)
							end
						end

					else
						sendMessage(localPlayer, "[ОШИБКА] Максимальная вместимость бака "..get("max_fuel").." литров", color_mes.red)
						return
					end
				else
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 107 then--документы тс
			local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..id2.."'" )
			if result[1]["COUNT()"] == 1 then
				local result = sqlite( "SELECT * FROM car_db WHERE number = '"..id2.."'" )

				me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." "..id2)

				do_chat(localPlayer, "Налог т/с оплачен на "..result[1]["taxation"].." дней - "..playername)
				do_chat(localPlayer, "Установлен "..result[1]["stage"].." stage - "..playername)
			end
			return

		elseif id1 == 106 then--документы дома
			local result = sqlite( "SELECT COUNT() FROM house_db WHERE number = '"..id2.."'" )
			if result[1]["COUNT()"] == 1 then
				local result = sqlite( "SELECT * FROM house_db WHERE number = '"..id2.."'" )

				me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." "..id2)

				do_chat(localPlayer, "Налог дома оплачен на "..result[1]["taxation"].." дней - "..playername)
			end
			return

		elseif id1 == 10 or id1 == 105 or id1 == 2 or id1 == 50 then--документы копа, паспорт, права, лиц на оружие
			local id,player = getPlayerId(id2)
			if id then
				me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." на имя "..id)
			elseif id1 == 10 or id1 == 105 then
				me_chat(localPlayer, playername.." показал(а) чужой "..info_png[id1][1])
			elseif id1 == 2 then
				me_chat(localPlayer, playername.." показал(а) чужие "..info_png[id1][1])
			elseif id1 == 50 then
				me_chat(localPlayer, playername.." показал(а) чужую "..info_png[id1][1])
			end
			return

		elseif weapon[id1] ~= nil then--оружие
			giveWeapon(localPlayer, weapon[id1][2], id2)
			me_chat(localPlayer, playername.." взял(а) в руку "..weapon[id1][1])
			id2 = 0

		elseif id1 == 11 then--планшет
			me_chat(localPlayer, playername.." достал(а) "..info_png[id1][1])

			triggerClientEvent( localPlayer, "event_inv_delet", localPlayer )
			triggerClientEvent( localPlayer, "event_tablet_fun", localPlayer )
			state_inv_player[playername] = 0
			state_gui_window[playername] = 1

			return

		elseif id1 == 23 then--ремонтный набор
			if vehicleid then
				if getSpeed(vehicleid) > 5 then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				elseif getElementHealth(vehicleid) == 1000 or getElementInterior(vehicleid) ~= 0 or getElementDimension(vehicleid) ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] Т/с не нуждается в ремонте", color_mes.red)
					return
				end

				id2 = id2 - 1

				fixVehicle ( vehicleid )
				vehicle_sethandling(vehicleid)

				me_chat(localPlayer, playername.." починил(а) т/с")
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 25 then--ключ от дома
			local h = id2
			local result = sqlite( "SELECT COUNT() FROM house_db WHERE number = '"..h.."'" )
			if result[1]["COUNT()"] == 1 then

				local result = sqlite( "SELECT * FROM house_db WHERE number = '"..h.."'" )
				if getElementDimension(localPlayer) == result[1]["world"] and getElementInterior(localPlayer) == interior_house[result[1]["interior"]][1] or isPointInCircle3D(result[1]["x"],result[1]["y"],result[1]["z"], x,y,z, get("house_bussiness_radius")) then
					local house_door = result[1]["door"]

					if house_door == 0 then
						house_door = 1
						me_chat(localPlayer, playername.." открыл(а) дверь дома")
					else
						house_door = 0
						me_chat(localPlayer, playername.." закрыл(а) дверь дома")
					end

					sqlite( "UPDATE house_db SET door = '"..house_door.."' WHERE number = '"..h.."'")

					return
				end
			end

			me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])
			return

		elseif id1 == 27 then--одежда
			local skin = getElementModel(localPlayer)

			setElementModel(localPlayer, id2)

			sqlite( "UPDATE account SET skin = '"..id2.."' WHERE name = '"..playername.."'")

			id2 = skin

			me_chat(localPlayer, playername.." переоделся(ась)")

		elseif id1 == 29 then--рожок

			if job[playername] == 15 then
				id2 = id2-1

				sendMessage(localPlayer, "Расстояние до оленя: "..split(getDistanceBetweenPoints2D(getElementData(localPlayer, "job_pos_15")[1],getElementData(localPlayer, "job_pos_15")[2], x,y), ".")[1].." метров", color_mes.yellow)
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не Охотник", color_mes.red)
				return
			end

		elseif id1 == 33 then--сонар

			if job[playername] == 17 then
				id2 = id2-1

				sendMessage(localPlayer, "Расстояние до груза: "..split(getDistanceBetweenPoints2D(getElementData(localPlayer, "job_pos_17")[1],getElementData(localPlayer, "job_pos_17")[2], x,y), ".")[1].." метров", color_mes.yellow)
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не Уборщик морского дна", color_mes.red)
				return
			end

		elseif id1 == 39 then--броник
			if getPedArmor(localPlayer) ~= 0 then
				sendMessage(localPlayer, "[ОШИБКА] На вас надет бронежилет", color_mes.red)
				return
			end

			if armour[playername] == 0 then
				armour[playername] = createObject (1242, x, y, z)
				setObjectScale(armour[playername], 1.7)
				exports["bone_attach"]:attachElementToBone (armour[playername], localPlayer, 3, 0,0.04,0.06, 5,0,0)
			end

			setPedArmor(localPlayer, 100)

			id2 = id2 - 1

			me_chat(localPlayer, playername.." надел(а) бронежилет")

		elseif id1 == 40 then--лом
			local count = 0
			local hour, minute = getTime()
			local x1,y1 = player_position( localPlayer )

			if vehicleid then
				sendMessage(localPlayer, "[ОШИБКА] Вы в т/с", color_mes.red)
				return
			end

			if hour >= 0 and hour <= 5 then
				for k,v in pairs(sqlite( "SELECT * FROM house_db" )) do
					if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) and robbery_player[playername] == 0 then
						local time_rob = 1--время для ограбления

						id2 = id2 - 1

						count = count+1

						robbery_player[playername] = 1

						me_chat(localPlayer, playername.." взломал(а) дверь")

						sendMessage(localPlayer, "Вы начали взлом", color_mes.yellow )
						sendMessage(localPlayer, "[TIPS] Не покидайте место ограбления "..time_rob.." мин", color_mes.color_tips)

						police_chat(localPlayer, "[ДИСПЕТЧЕР] Ограбление "..v["number"].." дома, GPS координаты [X  "..x1..", Y  "..y1.."], подозреваемый "..playername)

						robbery_timer[playername] = setTimer(robbery, (time_rob*10000), 1, localPlayer, get("zakon_robbery_crimes"), 1000, v["x"],v["y"],v["z"], get("house_bussiness_radius"), "house - "..v["number"])

						triggerClientEvent( localPlayer, "createHudTimer", localPlayer, (time_rob*10))
						break
					end
				end

				for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do
					if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) and robbery_player[playername] == 0 then
						local time_rob = 1--время для ограбления

						id2 = id2 - 1

						count = count+1

						robbery_player[playername] = 1

						me_chat(localPlayer, playername.." взломал(а) дверь")

						sendMessage(localPlayer, "Вы начали взлом", color_mes.yellow )
						sendMessage(localPlayer, "[TIPS] Не покидайте место ограбления "..time_rob.." мин", color_mes.color_tips)

						police_chat(localPlayer, "[ДИСПЕТЧЕР] Ограбление "..v["number"].." бизнеса, GPS координаты [X  "..x1..", Y  "..y1.."], подозреваемый "..playername)

						robbery_timer[playername] = setTimer(robbery, (time_rob*10000), 1, localPlayer, get("zakon_robbery_crimes"), 1000, v["x"],v["y"],v["z"], get("house_bussiness_radius"), "business - "..v["number"])

						triggerClientEvent( localPlayer, "createHudTimer", localPlayer, (time_rob*10))
						break
					end
				end

				if isPointInCircle3D(2144.18359375,1635.2705078125,993.57611083984, x,y,z, 10) and robbery_player[playername] == 0 then
					local time_rob = 1--время для ограбления

					id2 = id2 - 1

					count = count+1

					robbery_player[playername] = 1

					me_chat(localPlayer, playername.." взломал(а) сейф")

					sendMessage(localPlayer, "Вы начали взлом", color_mes.yellow )
					sendMessage(localPlayer, "[TIPS] Не покидайте место ограбления "..time_rob.." мин", color_mes.color_tips)

					police_chat(localPlayer, "[ДИСПЕТЧЕР] Ограбление Казино Калигула, подозреваемый "..playername)

					robbery_timer[playername] = setTimer(robbery, (time_rob*10000), 1, localPlayer, get("zakon_robbery_crimes"), 2000, 2144.18359375,1635.2705078125,993.57611083984, 10, "Casino Caligulas")
					
					triggerClientEvent( localPlayer, "createHudTimer", localPlayer, (time_rob*10))
				end

				if count == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Нужно быть около дома, бизнеса или в хранилище казино калигула; Вы уже начали ограбление", color_mes.red)
					return
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Ограбление доступно с 0 до 6 часов игрового времени", color_mes.red)
				return
			end

		elseif id1 == 46 then--радар
			if speed_car_device[playername] == 0 then
				speed_car_device[playername] = 1

				me_chat(localPlayer, playername.." включил(а) "..info_png[id1][1])
			else
				speed_car_device[playername] = 0

				me_chat(localPlayer, playername.." выключил(а) "..info_png[id1][1])
			end
			return

		elseif id1 == 51 then--джетпак
			if isPedWearingJetpack ( localPlayer ) then
				setPedWearingJetpack ( localPlayer, false )

				me_chat(localPlayer, playername.." снял(а) "..info_png[id1][1])
			else
				setPedWearingJetpack ( localPlayer, true )

				me_chat(localPlayer, playername.." надел(а) "..info_png[id1][1])
			end
			return

		elseif id1 == 52 then--кислородный балон
			if getElementData(localPlayer, "OxygenLevel") then
				sendMessage(localPlayer, "[ОШИБКА] На вас надет кислородный балон", color_mes.red)
				return
			end

			id2 = id2 - 1

			triggerClientEvent( localPlayer, "event_setPedOxygenLevel_fun", localPlayer )

			me_chat(localPlayer, playername.." надел(а) "..info_png[id1][1])

		elseif id1 == 57 then--алкостестер
			id2 = 0
			local alcohol_test = alcohol[playername]/100
			
			me_chat(localPlayer, playername.." подул(а) в "..info_png[id1][1])
			do_chat(localPlayer, info_png[id1][1].." показал "..alcohol_test.." промилле - "..playername)

			if alcohol_test >= get("zakon_alcohol") then
				addcrimes(localPlayer, get("zakon_alcohol_crimes"))
			end

		elseif id1 == 58 then--наркостестер
			id2 = 0
			local drugs_test = drugs[playername]
			
			me_chat(localPlayer, playername.." смочил(а) слюной палочку")
			do_chat(localPlayer, info_png[id1][1].." показал "..drugs_test.."% зависимости - "..playername)

			if drugs_test >= get("zakon_drugs") then
				addcrimes(localPlayer, get("zakon_drugs_crimes"))
			end

		elseif id1 == 59 then--налог дома
			local count = 0
			for k,v in pairs(sqlite( "SELECT * FROM house_db" )) do
				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) then
					sqlite( "UPDATE house_db SET taxation = taxation + '"..id2.."' WHERE number = '"..v["number"].."'")
					
					me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2].." и оплатил(а) "..v["number"].." дом")

					id2 = 0
					count = 1
					break
				end
			end

			if count == 0 then
				sendMessage(localPlayer, "[ОШИБКА] Вы должны быть около дома", color_mes.red)
				return
			end

		elseif id1 == 60 then--налог бизнеса
			local count = 0
			for k,v in pairs(sqlite( "SELECT * FROM business_db" )) do
				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) then
					sqlite( "UPDATE business_db SET taxation = taxation + '"..id2.."' WHERE number = '"..v["number"].."'")
					
					me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2].." и оплатил(а) "..v["number"].." бизнес")

					id2 = 0
					count = 1
					break
				end
			end

			if count == 0 then
				sendMessage(localPlayer, "[ОШИБКА] Вы должны быть около бизнеса", color_mes.red)
				return
			end
		
		elseif id1 == 61 then--налог авто
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)
				local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
				if result[1]["COUNT()"] == 1 then
					sqlite( "UPDATE car_db SET taxation = taxation + '"..id2.."' WHERE number = '"..plate.."'")

					me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2].." и оплатил(а) "..plate.." т/с")

					id2 = 0
				else
					sendMessage(localPlayer, "[ОШИБКА] Т/с не найдено", color_mes.red)
					return
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 63 then--gps навигатор
			if gps_device[playername] == 0 then
				gps_device[playername] = 1

				me_chat(localPlayer, playername.." включил(а) "..info_png[id1][1])
			else
				gps_device[playername] = 0

				me_chat(localPlayer, playername.." выключил(а) "..info_png[id1][1])
			end
			return

		elseif id1 == 64 then--лицензии
			if id2 == 1 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Таксист")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 2 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Мусоровозчик")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 3 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Инкассатор")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 4 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Рыболов")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 5 then
				if getElementModel(localPlayer) ~= 61 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 61", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Пилот")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 6 then
				if (crimes[playername] < get("crimes_giuseppe")) then
			
					sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..get("crimes_giuseppe").." преступлений", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Угонщик")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 7 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Дальнобойщик")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 8 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Перевозчик оружия")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 9 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Водитель автобуса")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 10 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				elseif getElementModel(localPlayer) ~= 274 and getElementModel(localPlayer) ~= 275 and getElementModel(localPlayer) ~= 276 and getElementModel(localPlayer) ~= 145 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 274,275,276,145", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Парамедик")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 11 then
				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Уборщик улиц")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 12 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				elseif getElementModel(localPlayer) ~= 277 and getElementModel(localPlayer) ~= 278 and getElementModel(localPlayer) ~= 279 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 277,278,279", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Пожарный")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 13 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				elseif getElementModel(localPlayer) ~= 285 and getElementModel(localPlayer) ~= 75 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 285,75", color_mes.red)
					return
				elseif search_inv_player_2_parameter(localPlayer, 10) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу SWAT")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 14 then
				if getElementModel(localPlayer) ~= 158 and getElementModel(localPlayer) ~= 198 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 158,198", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Фермер")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 15 then
				if getElementModel(localPlayer) ~= 312 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 312", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Охотник")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 16 then
				if getElementModel(localPlayer) ~= 155 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 155", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Развозчик пиццы")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 17 then
				if getElementModel(localPlayer) ~= 311 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 311", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Уборщик морского дна")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 18 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				elseif getElementModel(localPlayer) ~= 284 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 284", color_mes.red)
					return
				elseif search_inv_player_2_parameter(localPlayer, 10) == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Транспортный детектив")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 19 then
				if crimes[playername] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] У вас плохая репутация", color_mes.red)
					return
				elseif getElementModel(localPlayer) ~= 277 and getElementModel(localPlayer) ~= 278 and getElementModel(localPlayer) ~= 279 then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде 277,278,279", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Спасатель")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			elseif id2 == 20 then
				local mafia = search_inv_player_2_parameter(localPlayer, 85)

				if crimes[playername] < get("crimes_kill") then
					sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..get("crimes_kill").." преступлений", color_mes.red)
					return
				elseif mafia == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Вы не член банды", color_mes.red)
					return
				end

				local skin = false
				for k,v in pairs(name_mafia[mafia][2]) do
					if v == getElementModel(localPlayer) then
						skin = true
						break
					end
				end

				if not skin then
					sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде своей банды", color_mes.red)
					return
				end

				if job[playername] == 0 then
					job[playername] = id2

					me_chat(localPlayer, playername.." вышел(ла) на работу Киллер")
				else
					job[playername] = 0

					me_chat(localPlayer, playername.." закончил(а) работу")
				end
			end

			if job[playername] == 0 then
				job_0(playername)
				car_theft_fun(playername)
			elseif job[playername] ~= 0 then
				setElementData(localPlayer, "job_player", job[playername])
				job_timer2(localPlayer)
				rental_car(localPlayer, job[playername])
			end

			return

		elseif id1 == 65 then--инкассаторский сумка
			local randomize = id2

			id2 = 0

			me_chat(localPlayer, playername.." открыл(а) "..info_png[id1][1])

			sendMessage(localPlayer, "Вы получили "..randomize.."$", color_mes.green)

			addcrimes(localPlayer, get("zakon_65_crimes"))

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+randomize, playername )

		elseif id1 == 66 then--ящик с оружием
			local array_weapon = {9,12,13,14,15,17,18,19,26,34,41}

			local randomize = random(1,#array_weapon)

			me_chat(localPlayer, playername.." открыл(а) "..info_png[id1][1])

			inv_player_delet(localPlayer, id1, id2)
			inv_player_empty(localPlayer, array_weapon[randomize], 25)

			addcrimes(localPlayer, get("zakon_66_crimes"))

			return

		elseif id1 == 77 then--жетон
			if vehicleid then
				sendMessage(localPlayer, "[ОШИБКА] Вы в т/с", color_mes.red)
				return
			end

			if isPointInCircle3D(x,y,z, station[1][1],station[1][2],station[1][3], station[1][4]) then
				setElementPosition(localPlayer, station[2][1],station[2][2],station[2][3])
				id2 = id2 - 1
			elseif isPointInCircle3D(x,y,z, station[2][1],station[2][2],station[2][3], station[2][4]) then
				setElementPosition(localPlayer, station[3][1],station[3][2],station[3][3])
				id2 = id2 - 1
			elseif isPointInCircle3D(x,y,z, station[3][1],station[3][2],station[3][3], station[3][4]) then
				setElementPosition(localPlayer, station[1][1],station[1][2],station[1][3])
				id2 = id2 - 1
			else 
				sendMessage(localPlayer, "[ОШИБКА] Вы должны быть около вокзала", color_mes.red)
				return
			end

		elseif id1 == 79 then--чек

			if (not isPointInCircle3D(x,y,z, 2308.81640625,-13.25,26.7421875, 5)) then
			
				sendMessage(localPlayer, "[ОШИБКА] Вы не около банка", color_mes.red)
				return
			end

			local randomize = id2

			id2 = 0

			me_chat(localPlayer, playername.." обналичил(а) "..info_png[id1][1].." "..randomize.." "..info_png[id1][2])

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+randomize, playername )

		elseif id1 == 81 then--динамит
			local count = false

			for k,vehicleid in pairs(getElementsByType("vehicle")) do
				local x1,y1,z1 = getElementPosition( vehicleid )
				if (isPointInCircle3D(x,y,z, x1,y1,z1, 5) and getElementModel(vehicleid) == 428) then
					setTimer(function( vehicleid )
						blowVehicle(vehicleid)
					end, 5000, 1, vehicleid)

					me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1])
					count = true
					id2 = id2-1
					break
				end
			end

			if (not count) then
			
				sendMessage(localPlayer, "[ОШИБКА] Рядом нет инкассаторской машины", color_mes.red)
				return
			end

		elseif id1 == 84 then--отмычка
			if(vehicleid) then
			
				if(job[playername] == 6) then
				
					if(getElementData(localPlayer, "job_vehicleid")[1] == vehicleid) then
					
						id2 = id2-1

						setVehicleEngineState(vehicleid, true)

						me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1])
					
					else
					
						sendMessage(localPlayer, "[ОШИБКА] Это не то т/с", color_mes.red)
						return
					end
				
				else
				
					sendMessage(localPlayer, "[ОШИБКА] Вы не Угонщик", color_mes.red)
					return
				end
			
			else
				local count = 0
				for k,v in pairs(getElementsByType("vehicle")) do
					local pos = {getElementPosition(v)}

					if(job[playername] == 6) then
						if isPointInCircle3D(x,y,z, pos[1],pos[2],pos[3], 5) and getElementData(localPlayer, "job_vehicleid")[1] == v then
							setVehicleLocked(v, false)

							id2 = id2-1
							count = 1

							me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1])
							break
						end
					end
				end

				if count == 0 then
					sendMessage(localPlayer, "[ОШИБКА] Рядом нет нужного т/с", color_mes.red)
					return
				end
			end

		elseif(id1 == 85)then--повязка
			local count = 0
			local count2 = 0
			do_chat(localPlayer, "на шее "..info_png[id1][1].." "..getTeamName(name_mafia[id2][1]).." - "..playername)

			sendMessage(localPlayer, "====[ ПОД КОНТРОЛЕМ "..getTeamName(name_mafia[id2][1]).." ]====", color_mes.yellow)

			for k,v in pairs(guns_zone) do
				if(v[2] == id2) then
				
					count = count+1

					for k1,v1 in pairs(sqlite( "SELECT * FROM business_db" )) do
					
						if(isInsideRadarArea(v[1], v1["x"],v1["y"])) then
						
							count2 = count2+1
						end
					end
				end
			end

			sendMessage(localPlayer, "Территорий: "..count..", Доход: "..(count*get("money_guns_zone")).."$", color_mes.yellow)
			sendMessage(localPlayer, "Бизнесов: "..count2..", Доход: "..(count2*get("money_guns_zone_business")).."$", color_mes.yellow)
			return

		elseif id1 == 87 then--лиц. забойщика
			if job[playername] == 0 then
				job[playername] = 21

				setElementData(localPlayer, "job_player", job[playername])
				job_timer2(localPlayer)

				me_chat(localPlayer, playername.." вышел(ла) на работу Забойщик скота на "..id2.." скотобойне")
			else
				job[playername] = 0

				job_0(playername)
				car_theft_fun(playername)

				me_chat(localPlayer, playername.." закончил(а) работу")
			end
			return

		elseif id1 == 91 then--ордер
			me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." "..info_png[id1][id2+2])
			return

		elseif id1 == 94 then--квадрокоптер
			if vehicleid then
				sendMessage(localPlayer, "[ОШИБКА] Вы в т/с", color_mes.red)
				return
			end

			if drone[playername] == 0 then
				drone[playername] = 1

				triggerEvent("event_camhackm_fun", root, localPlayer)

				me_chat(localPlayer, playername.." достал(а) "..info_png[id1][1])
			else
				drone[playername] = 0

				triggerEvent("event_camhackm_fun", root, localPlayer)

				me_chat(localPlayer, playername.." убрал(а) "..info_png[id1][1])
			end
			return

		elseif id1 == 95 then--двигло
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				local count = false
				for k,v in pairs(car_cash_no) do
					if getElementModel(vehicleid) == v then
						count = true
						break
					end
				end

				if count then
					sendMessage(localPlayer, "[ОШИБКА] На это т/с нельзя установить двигатель", color_mes.red)
					return
				end

				setVehicleHandling(vehicleid, "engineAcceleration", getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"]*(id2*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["engineAcceleration"])
				setVehicleHandling(vehicleid, "maxVelocity", getOriginalHandling(getElementModel(vehicleid))["maxVelocity"]*(id2*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["maxVelocity"])
				setVehicleHandling(vehicleid, "brakeDeceleration", getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"]*(id2*get("car_stage_coef"))+getOriginalHandling(getElementModel(vehicleid))["brakeDeceleration"])

				sqlite( "UPDATE car_db SET stage = '"..id2.."' WHERE number = '"..plate.."'")

				vehicle_sethandling(vehicleid)

				me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 96 then--колеса
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				addVehicleUpgrade(vehicleid, id2)

				sqlite( "UPDATE car_db SET wheel = '"..id2.."' WHERE number = '"..plate.."'")

				me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 97 then--краска
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				local spl = color_table[id2]
				local r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4 = getVehicleColor ( vehicleid, true )
				setVehicleColor( vehicleid, spl[1], spl[2], spl[3], r2,g2,b2, spl[1], spl[2], spl[3], spl[1], spl[2], spl[3] )

				sqlite( "UPDATE car_db SET car_rgb = '"..spl[1]..","..spl[2]..","..spl[3].."' WHERE number = '"..plate.."'")

				me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 98 then--фара
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				local spl = color_table[id2]
				setVehicleHeadLightColor( vehicleid, spl[1], spl[2], spl[3] )

				sqlite( "UPDATE car_db SET headlight_rgb = '"..spl[1]..","..spl[2]..","..spl[3].."' WHERE number = '"..plate.."'")

				me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 99 then--винилы
			if vehicleid then
				local paint={
					[483]={"VehiclePaintjob_Camper_0"},-- camper
					[534]={"VehiclePaintjob_Remington_0","VehiclePaintjob_Remington_1","VehiclePaintjob_Remington_2"},-- remington
					[535]={"VehiclePaintjob_Slamvan_0","VehiclePaintjob_Slamvan_1","VehiclePaintjob_Slamvan_2"},-- slamvan
					[536]={"VehiclePaintjob_Blade_0","VehiclePaintjob_Blade_1","VehiclePaintjob_Blade_2"},-- blade
					[558]={"VehiclePaintjob_Uranus_0","VehiclePaintjob_Uranus_1","VehiclePaintjob_Uranus_2"},-- uranus
					[559]={"VehiclePaintjob_Jester_0","VehiclePaintjob_Jester_1","VehiclePaintjob_Jester_2"},-- jester
					[560]={"VehiclePaintjob_Sultan_0","VehiclePaintjob_Sultan_1","VehiclePaintjob_Sultan_2"},-- sultan
					[561]={"VehiclePaintjob_Stratum_0","VehiclePaintjob_Stratum_1","VehiclePaintjob_Stratum_2"},-- stratum
					[562]={"VehiclePaintjob_Elegy_0","VehiclePaintjob_Elegy_1","VehiclePaintjob_Elegy_2"},-- elegy
					[565]={"VehiclePaintjob_Flash_0","VehiclePaintjob_Flash_1","VehiclePaintjob_Flash_2"},-- flash
					[567]={"VehiclePaintjob_Savanna_0","VehiclePaintjob_Savanna_1","VehiclePaintjob_Savanna_2"},-- savanna
					[575]={"VehiclePaintjob_Broadway_0","VehiclePaintjob_Broadway_1"},-- broadway
					[576]={"VehiclePaintjob_Tornado_0","VehiclePaintjob_Tornado_1","VehiclePaintjob_Tornado_2"},-- tornado
				}

				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				local count = false
				for k,v in pairs(paint) do
					if getElementModel(vehicleid) == k then
						count = true
						break
					end
				end

				if count then
					setVehiclePaintjob( vehicleid, id2 )

					sqlite( "UPDATE car_db SET paintjob = '"..id2.."' WHERE number = '"..plate.."'")

					me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

					id2 = 0
				else
					sendMessage(localPlayer, "[ОШИБКА] На это т/с нельзя установить винилы", color_mes.red)
					return
				end
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 100 then--гидравлика
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				addVehicleUpgrade( vehicleid, 1087 )

				sqlite( "UPDATE car_db SET hydraulics = '1087' WHERE number = '"..plate.."'")

				me_chat(localPlayer, playername.." установил(а) "..info_png[id1][1])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 101 then--краска колес
			if vehicleid then
				local plate = getVehiclePlateText(vehicleid)

				if (getSpeed(vehicleid) > 5) then
					sendMessage(localPlayer, "[ОШИБКА] Остановите т/с", color_mes.red)
					return
				end

				local spl = color_table[id2]
				local r,g,b = getVehicleColor ( vehicleid, true )
				setVehicleColor( vehicleid, r,g,b, spl[1], spl[2], spl[3], r,g,b, r,g,b )

				sqlite( "UPDATE car_db SET wheel_rgb = '"..spl[1]..","..spl[2]..","..spl[3].."' WHERE number = '"..plate.."'")

				me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
				return
			end

		elseif id1 == 102 then-- уголовное дело
			addcrimes(localPlayer, id2)
			me_chat(localPlayer, playername.." прочитал(а) "..info_png[id1][1])
			id2 = 0

		elseif id1 == 104 then-- лотерея
			if loto[3] then
				me_chat(localPlayer, playername.." потер(ла) лотерейный билет")

				if loto[1] == id2 then
					local randomize = random(get("zp_loto")/2,get("zp_loto"))
					loto[3] = false

					inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+randomize, playername )
					sendMessage(root, "[НОВОСТИ] Лотерея объявляется закрытой, победителем стал "..playername..", выигрыш составил "..randomize.."$", color_mes.green)
				end

				id2 = 0
			else
				sendMessage(localPlayer, "[ОШИБКА] Лотерея закончилась", color_mes.red)
				return
			end

		elseif id1 == 112 then--овощи
			local count, count_harvest = 0, 0
			for h,v in pairs(harvest) do
				if not isPointInCircle3D(v[1][1],v[1][2],v[1][3], x,y,z, 2) then
					count = count+1
				end

				count_harvest = count_harvest+1
			end

			if getElementData(localPlayer, "task") ~= "TASK_SIMPLE_PLAYER_ON_FOOT" then
				sendMessage(localPlayer, "[ОШИБКА] Вы заняты другим делом", color_mes.red)
				return
			end

			if count == count_harvest then
				local v = harvest_time[id1]
				
				id2 = id2-1

				table.insert( harvest, { {x,y,z}, v[1], v[2], id1, playername, createPickup ( x, y, z, 3, harvest_icon_complete, 10000 ), createObject(v[4], x, y, z), false, v[5]} )

				setPedAnimation(localPlayer, "BOMBER", "BOM_Plant", -1, true, false, false, false)

				setTimer(function ()
					if isElement(localPlayer) then
						setPedAnimation(localPlayer, nil, nil)
					end
				end, (10*1000), 1)

				me_chat(localPlayer, playername.." посадил(а) "..info_png[id1][1])

				inv_player_delet( localPlayer, id1, id2, true, false )

				setElementData(resourceRoot, "harvest", harvest)
			else
				sendMessage(localPlayer, "[ОШИБКА] Вы слишком близко к другим растениям", color_mes.red)
				return
			end

		elseif id1 == 113 then--лейка
			local count, count2 = false, 0
			for k,v in pairs(harvest) do
				if isPointInCircle3D(v[1][1],v[1][2],v[1][3], x,y,z, 2) and not v[8] and v[2] > harvest_time[v[4]][3] then
					count, count2 = true, k
					break
				end
			end

			if getElementData(localPlayer, "task") ~= "TASK_SIMPLE_PLAYER_ON_FOOT" then
				sendMessage(localPlayer, "[ОШИБКА] Вы заняты другим делом", color_mes.red)
				return
			end

			if count then
				id2 = id2-1

				harvest[count2][2] = harvest[count2][2]-harvest_time[harvest[count2][4]][3]
				harvest[count2][8] = true

				object_attach(localPlayer, 321, 12, 0.15,0,0.3, 0,-90,0, (5*1000))

				setPedAnimation(localPlayer, "camera", "camstnd_idleloop", -1, true, false, false, false)

				setTimer(function ()
					if isElement(localPlayer) then
						setPedAnimation(localPlayer, nil, nil)
					end
				end, (5*1000), 1)

				me_chat(localPlayer, playername.." использовал(а) "..info_png[id1][1])

				setElementData(resourceRoot, "harvest", harvest)
			else
				sendMessage(localPlayer, "[ОШИБКА] Рядом нет растения, которое можно полить", color_mes.red)
				return
			end

		else
			if id1 == 1 then
				return
			end

			me_chat(localPlayer, playername.." показал(а) "..info_png[id1][1].." "..id2.." "..info_png[id1][2])
			return
		end

		--------------------------------------------------------------------------------------------------------------------------------
		if id2 == 0 then
			id1, id2 = 0, 0
		end

		inv_server_load( localPlayer, "player", id3, id1, id2, playername )
	end
end
addEvent( "event_use_inv", true )
addEventHandler ( "event_use_inv", root, use_inv )

-------------------------------команды игроков----------------------------------------------------------
addCommandHandler ( "sms",--смс игроку
function (localPlayer, cmd, id, ...)
	local playername = getPlayerName ( localPlayer )
	local text = ""

	if logged[playername] == 0 then
		return
	end
	
	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if not id or text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [текст]", color_mes.red)
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		sendMessage(localPlayer, "[SMS TO] "..id.." ["..getElementData(player, "player_id").."]: "..text, color_mes.yellow)
		sendMessage(player, "[SMS FROM] "..playername.." ["..getElementData(localPlayer, "player_id").."]: "..text, color_mes.yellow)
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

function win_roulette( localPlayer, cash, ratio )
	local playername = getPlayerName ( localPlayer )
	local money = cash*ratio

	sendMessage(localPlayer, "Вы заработали "..money.."$ X"..ratio, color_mes.green)

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+money, playername )
end
addEvent("event_win_roulette", true)
addEventHandler("event_win_roulette", root, win_roulette)

function roulette_fun (localPlayer, id, cash, randomize)--играть в рулетку
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local id = tostring(id)
	local cash = tonumber(cash)
	local randomize = tonumber(randomize)
	local Red = {1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36}
	local Black = {2,4,6,8,10,11,13,15,17,20,22,24,26,28,29,31,33,35}
	local to1 = {1,4,7,10,13,16,19,22,25,28,31,34}
	local to2 = {2,5,8,11,14,17,20,23,26,29,32,35}
	local to3 = {3,6,9,12,15,18,21,24,27,30,33,36}

	if logged[playername] == 0 then
		return
	end

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

	if id == "RED" then
		for k,v in pairs(Red) do
			if randomize == v then
				win_roulette(localPlayer, cash, 2)
				return
			end
		end

	elseif id == "BLACK" then
		for k,v in pairs(Black) do
			if randomize == v then
				win_roulette(localPlayer, cash, 2)
				return
			end
		end

	elseif id == "EVEN" and randomize%2 == 0 then
		win_roulette(localPlayer, cash, 2)
		return

	elseif id == "ODD" and randomize%2 == 1 then
		win_roulette(localPlayer, cash, 2)
		return

	elseif id == "1-18" and randomize >= 1 and randomize <= 18 then
		win_roulette(localPlayer, cash, 2)
		return

	elseif id == "19-36" and randomize >= 19 and randomize <= 36 then
		win_roulette(localPlayer, cash, 2)
		return

	elseif id == "1-12" and randomize >= 1 and randomize <= 12 then
		win_roulette(localPlayer, cash, 3)
		return

	elseif id == "13-24" and randomize >= 13 and randomize <= 24 then
		win_roulette(localPlayer, cash, 3)
		return

	elseif id == "25-36" and randomize >= 25 and randomize <= 36 then
		win_roulette(localPlayer, cash, 3)
		return

	elseif id == "3-1" then
		for k,v in pairs(to1) do
			if randomize == v then
				win_roulette(localPlayer, cash, 3)
				return
			end
		end

	elseif id == "3-2" then
		for k,v in pairs(to2) do
			if randomize == v then
				win_roulette(localPlayer, cash, 3)
				return
			end
		end

	elseif id == "3-3" then
		for k,v in pairs(to3) do
			if randomize == v then
				win_roulette(localPlayer, cash, 3)
				return
			end
		end
		
	else
		id = tonumber(id)

		if id and id >= 0 and id <= 36 then
			if randomize == id then
				win_roulette(localPlayer, cash, 36)
				return
			end
		end
	end
end
addEvent("event_roulette_fun", true)
addEventHandler("event_roulette_fun", root, roulette_fun)

function slots (localPlayer, cash, randomize1, randomize2, randomize3)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

	if (randomize1 == randomize2 and randomize1 == randomize3) then
		win_roulette( localPlayer, cash, 25 )
	end
end
addEvent("event_slots", true)
addEventHandler("event_slots", root, slots)

function insider_track (localPlayer, cash, randomize, horse, horse_player)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

	sendMessage(localPlayer, "Финишировала "..horse.." лошадь", color_mes.yellow)

	if horse == horse_player then
		win_roulette( localPlayer, cash, randomize )
	end
end
addEvent("event_insider_track", true)
addEventHandler("event_insider_track", root, insider_track)

function fortune_fun (localPlayer, cash, value, randomize)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

	if value == randomize then
		win_roulette( localPlayer, cash, randomize )
	end
end
addEvent("event_fortune_fun", true)
addEventHandler("event_fortune_fun", root, fortune_fun)

local poker_coef = {
	[1] = {0,1,2,3,4,6,9,25,50,250},
	[2] = {0,2,4,6,8,12,18,50,100,500},
	[3] = {0,3,6,9,12,18,27,75,150,750},
	[4] = {0,4,8,12,16,24,36,100,200,1000},
	[5] = {0,5,10,15,20,30,45,125,250,4000},
}
local poker_name = {"","пара","две пары","тройка","стрит","флеш","фулл-хауз","каре","стрит флеш","флеш рояль"}
function poker_win( localPlayer, value, cash, coef, token )
	local playername = getPlayerName(localPlayer)
	local spl = split(value, ",")
	local card = {}
	local cash = tonumber(cash)
	local coef = tonumber(coef)

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

	for k,v in pairs(spl) do
		table.insert(card, v)
	end

	table.sort( card )

	local card_i = ""
	local card_s = ""

	for k,v in ipairs(card) do
		card_i = card_i..split(v, "cdhs")[1]
		card_s = card_s..split(v, "0123456789")[1]
		--print(k,v)
	end

	--выигрышные комбанции
	if card_i == "101112131" and (card_s == "ccccc" or card_s == "ddddd" or card_s == "hhhhh" or card_s == "sssss") then
		sendMessage(localPlayer, poker_name[10], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][10] )
		--print("win 10")
		return
	end

	local table_win = {
		[1] = "106789",
		[2] = "1011789",
		[3] = "10111289",
		[4] = "101112139",
	}
	local text = ""
	for j=0,3 do
		for i=2+j,6+j do
			text = text..i
		end
		table.insert(table_win, text)
		text = ""
	end
	for k,v in pairs(table_win) do
		if card_i == v and (card_s == "ccccc" or card_s == "ddddd" or card_s == "hhhhh" or card_s == "sssss") then
			sendMessage(localPlayer, poker_name[9], color_mes.yellow)
			win_roulette( localPlayer, token, poker_coef[coef][9] )
			--print("win 9")
			return
		end
	end

	for i=1,5 do
		local count = 0
		for j=1,5 do
			if split(spl[i], "cdhs")[1] == split(spl[j], "cdhs")[1] then
				count = count+1
			end
		end

		if count == 4 then
			sendMessage(localPlayer, poker_name[8], color_mes.yellow)
			win_roulette( localPlayer, token, poker_coef[coef][8] )
			--print("win 8")
			return
		end
	end

	local table_win2 = {}
	for i=1,5 do
		local count = 0
		for j=1,5 do
			if split(spl[i], "cdhs")[1] == split(spl[j], "cdhs")[1] then
				count = count+1
			end
		end

		table.insert(table_win2, count)
	end
	local count1 = 0
	local count2 = 0
	for k,v in pairs(table_win2) do
		if v == 3 then
			count1 = count1+1
		elseif v == 2 then
			count2 = count2+1
		end
	end
	if count1 == 3 and count2 == 2 then
		sendMessage(localPlayer, poker_name[7], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][7] )
		--print("win 7")
		return
	end

	if (card_s == "ccccc" or card_s == "ddddd" or card_s == "hhhhh" or card_s == "sssss") then
		sendMessage(localPlayer, poker_name[6], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][6] )
		--print("win 6")
		return
	end

	for k,v in pairs(table_win) do
		if card_i == v then
			sendMessage(localPlayer, poker_name[5], color_mes.yellow)
			win_roulette( localPlayer, token, poker_coef[coef][5] )
			--print("win 5")
			return
		end
	end

	local table_win2 = {}
	for i=1,5 do
		local count = 0
		for j=1,5 do
			if split(spl[i], "cdhs")[1] == split(spl[j], "cdhs")[1] then
				count = count+1
			end
		end

		table.insert(table_win2, count)
	end
	local count1 = 0
	for k,v in pairs(table_win2) do
		if v == 3 then
			count1 = count1+1
		end
	end
	if count1 == 3 then
		sendMessage(localPlayer, poker_name[4], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][4] )
		--print("win 4")
		return
	end

	local table_win2 = {}
	for i=1,5 do
		local count = 0
		for j=1,5 do
			if split(spl[i], "cdhs")[1] == split(spl[j], "cdhs")[1] then
				count = count+1
			end
		end

		table.insert(table_win2, count)
	end
	local count1 = 0
	for k,v in pairs(table_win2) do
		if v == 2 then
			count1 = count1+1
		end
	end
	if count1 == 4 then
		sendMessage(localPlayer, poker_name[3], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][3] )
		--print("win 3")
		return
	end

	local table_win2 = {}
	for i=1,5 do
		local count = 0
		for j=1,5 do
			if split(spl[i], "cdhs")[1] == split(spl[j], "cdhs")[1] then
				count = count+1
			end
		end

		table.insert(table_win2, count)
	end
	local count1 = 0
	for k,v in pairs(table_win2) do
		if v == 2 then
			count1 = count1+1
		end
	end
	if count1 == 2 then
		sendMessage(localPlayer, poker_name[2], color_mes.yellow)
		win_roulette( localPlayer, token, poker_coef[coef][2] )
		--print("win 2")
		return
	end

	--print(card_i,card_s)
end
addEvent("event_poker_win", true)
addEventHandler("event_poker_win", root, poker_win)

local blackjack_card = {"2:2", "3:3", "4:4", "5:5", "6:6", "7:7", "8:8", "9:9", "10:10", "В:10", "Д:10", "К:10", "Т:11"}
function blackjack (localPlayer, cmd, value, ...)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	elseif search_inv_player(localPlayer, 93, 1) == 0 then
		sendMessage(localPlayer, "[ОШИБКА] У вас нет "..info_png[93][1], color_mes.red)
		return
	end

	if not value then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [invite | take | open]", color_mes.red)
		return
	end

	if value == "invite" then
		local id = arg[1]
		local cash = tonumber(arg[2])

		if not id or not cash then
			sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." invite [ИД игрока] [сумма]", color_mes.red)
			return
		elseif cash < 1 then
			return
		end

		if cash > search_inv_player_2_parameter(localPlayer, 1) then
			sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
			return
		end

		local id,player = getPlayerId(id)
			
		if id then
			local x1,y1,z1 = getElementPosition(player)
			if isPointInCircle3D(x,y,z, x1,y1,z1, 10) then

				if arrest[id] ~= 0 then
					sendMessage(localPlayer, "[ОШИБКА] Игрок в тюрьме", color_mes.red)
					return
				elseif accept_player[id][1] then
					sendMessage(localPlayer, "[ОШИБКА] Игрок играет", color_mes.red)
					return
				elseif accept_player[playername][1] then
					sendMessage(localPlayer, "[ОШИБКА] Вы играете", color_mes.red)
					return
				elseif cash > array_player_2[id][1] then
					sendMessage(localPlayer, "[ОШИБКА] У игрока недостаточно средств", color_mes.red)
					return
				elseif playername == id then
					sendMessage(localPlayer, "[ОШИБКА] На столько всё плохо?", color_mes.red)
					return
				end

				accept_player[id] = {false, localPlayer, cash, false}
				accept_player[playername] = {false, player, cash, false}

				me_chat(localPlayer, playername.." предложил(а) "..id.." сыграть в блэкджек на сумму "..cash.."$")
				sendMessage(player, "/accept yes - согласиться", color_mes.yellow)
				sendMessage(player, "/accept no - отказаться", color_mes.yellow)
				
			else
				sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
		end

	elseif value == "take" then
		if not accept_player[playername][1] then
			sendMessage(localPlayer, "[ОШИБКА] Вы не играете", color_mes.red)
			return
		elseif accept_player[playername][4] then
			sendMessage(localPlayer, "[ОШИБКА] Вы готовы вскрыть карты", color_mes.red)
			return
		elseif #game[playername] == 5 then
			sendMessage(localPlayer, "[ОШИБКА] У вас 5 карт", color_mes.red)
			return
		end

		if logged[getPlayerName(accept_player[playername][2])] == 1 then
			local x1,y1,z1 = getElementPosition(accept_player[playername][2])
			if not isPointInCircle3D(x,y,z, x1,y1,z1, 10) then
				sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
				return
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
			return
		end

		me_chat(localPlayer, playername.." взял(а) карту")

		local randomize = random(1,#blackjack_card)
		local spl = blackjack_card[randomize]

		--[[while true do --не оригинал
			local count = 0
			for k,v in pairs(game[playername]) do
				if split(v, ":")[1] == split(spl, ":")[1] then
					count = count + 1
				end
			end

			if count < 4 then
				break

			else
				randomize = random(1,#blackjack_card)
				spl = blackjack_card[randomize]
			end
		end]]

		table.insert(game[playername], blackjack_card[randomize])

		local point = 0
		for k,v in pairs(game[playername]) do
			point = point+tonumber(split(v, ":")[2])
		end

		sendMessage(localPlayer, "Вы взяли "..split(spl, ":")[1]..", у вас "..point.." очков", color_mes.yellow)

		if point >= 21 then
			blackjack(localPlayer, "", "open")
		end

	elseif value == "open" then
		if not accept_player[playername][1] then
			sendMessage(localPlayer, "[ОШИБКА] Вы не играете", color_mes.red)
			return
		end

		if logged[getPlayerName(accept_player[playername][2])] == 1 then
			local x1,y1,z1 = getElementPosition(accept_player[playername][2])
			if not isPointInCircle3D(x,y,z, x1,y1,z1, 10) then
				sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
				return
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
			return
		end

		if not accept_player[getPlayerName(accept_player[playername][2])][4] then
			me_chat(localPlayer, playername.." готов(а) вскрыть карты")

			accept_player[playername][4] = true
		else
			me_chat(localPlayer, playername.." вскрывает карты")

			accept_player[playername][4] = true

			local point = 0
			for k,v in pairs(game[playername]) do
				point = point+tonumber(split(v, ":")[2])
			end

			local point2 = 0
			for k,v in pairs(game[getPlayerName(accept_player[playername][2])]) do
				point2 = point2+tonumber(split(v, ":")[2])
			end

			do_chat(localPlayer, point.." очков - "..playername)
			do_chat(localPlayer, point2.." очков - "..getPlayerName(accept_player[playername][2]))

			if point == point2 then

			elseif point < point2 and point2 <= 21 or point2 == 21 then
				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-accept_player[playername][3], playername )

				win_roulette(accept_player[playername][2], accept_player[playername][3], 1)
			elseif point > point2 and point <= 21 or point == 21 then
				inv_server_load( accept_player[playername][2], "player", 0, 1, array_player_2[getPlayerName(accept_player[playername][2])][1]-accept_player[playername][3], playername )

				win_roulette(localPlayer, accept_player[playername][3], 1)
			else

			end

			game[getPlayerName(accept_player[playername][2])] = {}
			game[playername] = {}
			accept_player[getPlayerName(accept_player[playername][2])] = {false,false,false,false}
			accept_player[playername] = {false,false,false,false}
		end
	end
end
addCommandHandler ( "blackjack", blackjack)
addEvent("event_blackjack", true)
addEventHandler("event_blackjack", root, blackjack)

function accept (localPlayer, cmd, value)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return

	elseif not value then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [yes | no]", color_mes.red)
		return

	elseif not accept_player[playername][2] then
		sendMessage(localPlayer, "[ОШИБКА] У вас нет предложений", color_mes.red)
		return
	end

	if value == "yes" then
		if accept_player[playername][1] then
			sendMessage(localPlayer, "[ОШИБКА] Вы играете", color_mes.red)
			return
		end

		accept_player[playername][1] = true
		accept_player[getPlayerName(accept_player[playername][2])][1] = true

		me_chat(localPlayer, playername.." согласился(ась) с "..getPlayerName(accept_player[playername][2]).." сыграть в блэкджек на сумму "..accept_player[playername][3].."$")

		sendMessage(localPlayer, "/blackjack take - взять карту", color_mes.yellow)
		sendMessage(localPlayer, "/blackjack open - вскрыть карты", color_mes.yellow)
	elseif value == "no" then
		me_chat(localPlayer, playername.." отказался(ась) от предложения "..getPlayerName(accept_player[playername][2]).." сыграть в блэкджек на сумму "..accept_player[playername][3].."$")

		game[playername] = {}
		accept_player[playername] = {false,false,false,false}
	end
end
addCommandHandler ( "accept", accept)
addEvent("event_accept", true)
addEventHandler("event_accept", root, accept)

addCommandHandler( "setchanel",--//сменить канал в рации
function( localPlayer, cmd, id )

	local playername = getPlayerName ( localPlayer )
	local id = tonumber(id)

	if not id then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [канал]", color_mes.red)
		return
	
	elseif (logged[playername] == 0 or id <= 0) then
	
		return
	
	elseif (amount_inv_player_1_parameter(localPlayer, 80) == 0) then
	
		sendMessage(localPlayer, "[ОШИБКА] У вас нет рации", color_mes.red)
		return
	end

	inv_player_delet(localPlayer, 80, search_inv_player_2_parameter(localPlayer, 80), true)

	inv_player_empty(localPlayer, 80, id)

	me_chat(localPlayer, playername.." сменил(а) канал в рации на "..id)
end)

addCommandHandler ( "r",--рация
function (localPlayer, cmd, ...)
	local playername = getPlayerName ( localPlayer )
	local text = ""

	if logged[playername] == 0 then
		return
	elseif (amount_inv_player_1_parameter(localPlayer, 80) == 0) then
		sendMessage(localPlayer, "[ОШИБКА] У вас нет рации", color_mes.red)
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [текст]", color_mes.red)
		return
	end

	local radio_chanel = search_inv_player_2_parameter(localPlayer, 80)

	if(radio_chanel == get("police_chanel")) then
		if search_inv_player_2_parameter(localPlayer, 10) ~= 0 then
			police_chat(localPlayer, "[РАЦИЯ "..radio_chanel.." K] "..playername.." ["..getElementData(localPlayer, "player_id").."]: "..text)
		end
	elseif(radio_chanel == get("admin_chanel")) then
		if search_inv_player_2_parameter(localPlayer, 44) ~= 0 then
			admin_chat(localPlayer, "[РАЦИЯ "..radio_chanel.." K] Админ "..search_inv_player_2_parameter(localPlayer, 44).." "..info_png[44][2].." "..playername.." ["..getElementData(localPlayer, "player_id").."]: "..text)
		end
	else
		radio_chat(localPlayer, "[РАЦИЯ "..radio_chanel.." K] "..playername.." ["..getElementData(localPlayer, "player_id").."]: "..text, color_mes.green_rc)
	end
end)

addCommandHandler("ec",--эвакуция авто
function (localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local id = tonumber(id)
	local cash = 500

	if logged[playername] == 0 then
		return
	end

	if arrest[playername] ~= 0 or enter_house[playername][1] == 1 or enter_job[playername] == 1 or enter_business[playername] == 1 then
		return
	end

	if not id then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [номер т/с]", color_mes.red)
		return
	end

	if cash <= search_inv_player_2_parameter(localPlayer, 1) then
		for k,vehicleid in pairs(getElementsByType("vehicle")) do

			local plate = getVehiclePlateText(vehicleid)
			if id == tonumber(plate) then

				local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )
				if result[1]["COUNT()"] == 1 then

					local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
					for k,v in pairs(result) do
						
						if v["frozen"] == 0 then
							if v["evacuate"] == 1 then
								sendMessage(localPlayer, "[ОШИБКА] Т/с на эвакуаторе", color_mes.red)
								return
							end

							if search_inv_player(localPlayer, 6, id) ~= 0 then

								if (player_in_car_theft(tostring(id)) ~= 0) then
									sendMessage(localPlayer, "[ОШИБКА] Т/с угнали", color_mes.red)
									return
								end

								for k,player in pairs(getElementsByType("player")) do
									local vehicle = getPlayerVehicle(player)
									if vehicle == vehicleid then
										removePedFromVehicle ( player )
									end
								end

								if not getVehicleLandingGearDown(vehicleid) then
									setVehicleLandingGearDown(vehicleid,true)
								end

								setElementPosition(vehicleid, x+2,y,z+1)
								setElementRotation(vehicleid, 0,0,0)
								setElementDimension(vehicleid, 0)

								sqlite( "UPDATE car_db SET x = '"..(x+2).."', y = '"..y.."', z = '"..(z+1).."', fuel = '"..fuel[plate].."' WHERE number = '"..plate.."'")

								inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )

								sendMessage(localPlayer, "Вы эвакуировали т/с за "..cash.."$", color_mes.orange)

							else
								sendMessage(localPlayer, "[ОШИБКА] У вас нет ключа от этого т/с", color_mes.red)
							end
						else
							sendMessage(localPlayer, "[ОШИБКА] Т/с на штрафстоянке", color_mes.red)
						end
					end
				else
					sendMessage(localPlayer, "[ОШИБКА] Т/с не найдено", color_mes.red)
				end

				return
			end
		end

		local result = sqlite( "SELECT * FROM car_db WHERE number = '"..id.."'" )
		if result[1] then
			if result[1]["theft"] == 1 then
				sendMessage(localPlayer, "[ОШИБКА] Т/с в угоне", color_mes.red)
				return
			end
		end

		sendMessage(localPlayer, "[ОШИБКА] Т/с не найдено", color_mes.red)
	else
		sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..cash.."$", color_mes.red)
	end
end)

addCommandHandler("wc",--выдача чека
function (localPlayer, cmd, cash)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local cash = tonumber(cash)

	if not cash then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [сумма]", color_mes.red)
		return
	end

	if logged[playername] == 0 or cash < 1 or arrest[playername] ~= 0 then
		return
	end

	if cash > search_inv_player_2_parameter(localPlayer, 1) then
		sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
		return
	end

	if(inv_player_empty(localPlayer, 79, cash)) then
	
		me_chat(localPlayer, playername.." выписал(а) "..info_png[79][1].." "..cash.." "..info_png[79][2])

		inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-cash, playername )
	
	else
	
		sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
	end
end)

addCommandHandler("searchcar",--заявление на поиск тс
function (localPlayer, cmd, plate)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local plate = tonumber(plate)

	if not plate then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [номер т/с]", color_mes.red)
		return
	end

	local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )

	if logged[playername] == 0 then
		return
	elseif not result[1] then
		sendMessage(localPlayer, "[ОШИБКА] Т/с не найдено", color_mes.red)
		return
	elseif result[1]["theft"] == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Т/с не в угоне", color_mes.red)
		return
	end

	if(inv_player_delet(localPlayer, 108, 1, true)) then
		inv_player_empty(localPlayer, 109, plate)

		me_chat(localPlayer, playername.." написал(а) "..info_png[109][1].." "..plate)
	else
		sendMessage(localPlayer, "[ОШИБКА] У вас нет "..info_png[108][1], color_mes.red)
	end
end)

addCommandHandler ( "prison",--команда для копов (посадить игрока в тюрьму)
function (localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local cash = 100

	if logged[playername] == 0 then
		return
	end

	if not id then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока]", color_mes.red)
		return
	end

	if search_inv_player_2_parameter(localPlayer, 10) == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		local x1,y1,z1 = getElementPosition(player)
		if isPointInCircle3D(x,y,z, x1,y1,z1, 10) then

			if arrest[id] ~= 0 then
				sendMessage(localPlayer, "[ОШИБКА] Игрок в тюрьме", color_mes.red)
				return
			end

			if crimes[id] == 0 then
				sendMessage(localPlayer, "[ОШИБКА] Гражданин чист перед законом", color_mes.red)
				return
			end

			me_chat(localPlayer, playername.." посадил(а) "..id.." в камеру на "..(crimes[id]).." мин")

			arrest[id] = 1

			sendMessage(localPlayer, "Вы получили премию "..(cash*(crimes[id])).."$", color_mes.green )

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)+(cash*(crimes[id])), playername )
		else
			sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "lawyer",--выйти из тюряги за деньги
function (localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local cash = 1000

	if logged[playername] == 0 then
		return
	end

	if not id then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока]", color_mes.red)
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		local x1,y1,z1 = getElementPosition(player)
		if isPointInCircle3D(x,y,z, x1,y1,z1, 10) then

			if arrest[id] == 0 or arrest[id] == 2 then
				sendMessage(localPlayer, "[ОШИБКА] Игрок не в тюрьме", color_mes.red)
				return
			elseif crimes[id] == 1 then
				sendMessage(localPlayer, "[ОШИБКА] Маленький срок заключения", color_mes.red)
				return
			end

			if cash*crimes[id] > search_inv_player_2_parameter(localPlayer, 1) then
				sendMessage(localPlayer, "[ОШИБКА] У вас недостаточно средств", color_mes.red)
				return
			end

			me_chat(localPlayer, playername.." заплатил(а) залог за "..id.." в размере "..(cash*(crimes[id])).."$")

			sendMessage(player, "Ждите освобождения", color_mes.yellow)

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*(crimes[id])), playername )

			crimes[id] = 1
		else
			sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "search",--команда для копов (обыскать игрока)
function (localPlayer, cmd, value, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 then
		return
	end

	if not id or not value then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [player | car | house] [ИД игрока | номер т/с | номер дома]", color_mes.red)
		return
	end

	if search_inv_player_2_parameter(localPlayer, 10) == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Вы не полицейский", color_mes.red)
		return
	end

	if value == "player" then
		local id,player = getPlayerId(id)
		
		if id then
			local x1,y1,z1 = getElementPosition(player)

			if isPointInCircle3D(x,y,z, x1,y1,z1, 10) then
				me_chat(localPlayer, playername.." обыскал(а) "..id)

				search_inv_player_police( localPlayer, id )
			else
				sendMessage(localPlayer, "[ОШИБКА] Игрок далеко", color_mes.red)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
		end

	elseif value == "car" then
		for i,vehicleid in pairs(getElementsByType("vehicle")) do
			local x1,y1,z1 = getElementPosition(vehicleid)
			local plate = getVehiclePlateText(vehicleid)

			if (plate == id) then

				if (isPointInCircle3D(x,y,z, x1,y1,z1, 10.0)) then
				
					me_chat(localPlayer, playername.." обыскал(а) т/с под номером "..id)

					search_inv_car_police( localPlayer, id )
				else
				
					sendMessage(localPlayer, "[ОШИБКА] Т/с далеко", color_mes.red)
				end

				return
			end
		end

		sendMessage(localPlayer, "[ОШИБКА] Т/с не найдено", color_mes.red)

	elseif value == "house" then
		for i,v in pairs(sqlite( "SELECT * FROM house_db" )) do
			local id = tonumber(id)

			if (v["number"] == id) then

				if (isPointInCircle3D(x,y,z, v["x"],v["y"],v["z"], 10.0)) then
				
					me_chat(localPlayer, playername.." обыскал(а) дом под номером "..id)

					search_inv_house_police( localPlayer, id )
				else
				
					sendMessage(localPlayer, "[ОШИБКА] Дом далеко", color_mes.red)
				end

				return
			end
		end

		sendMessage(localPlayer, "[ОШИБКА] Дом не найден", color_mes.red)
	end
end)

addCommandHandler ( "sellhouse",--команда для риэлторов
function (localPlayer)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local house_count = 0
	local business_count = 0
	local job_count = 0

	if logged[playername] == 0 then
		return
	end

	if search_inv_player(localPlayer, 45, 1) == 0 then
		sendMessage(localPlayer, "[ОШИБКА] Вы не риэлтор", color_mes.red)
		return
	end

	if(search_inv_player_2_parameter(localPlayer, 1) < get("zakon_price_house")) then
	
		sendMessage(localPlayer, "[ОШИБКА] Стоимость домов составляет "..get("zakon_price_house").."$", color_mes.red)
		return
	end

	local result = sqlite( "SELECT COUNT() FROM house_db" )
	local house_number = result[1]["COUNT()"]
	for h,v in pairs(sqlite( "SELECT * FROM house_db" )) do
		if not isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")*2) then
			house_count = house_count+1
		end
	end

	local result = sqlite( "SELECT COUNT() FROM business_db" )
	local business_number = result[1]["COUNT()"]
	for h,v in pairs(sqlite( "SELECT * FROM business_db" )) do 
		if not isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")*2) then
			business_count = business_count+1
		end
	end

	local job_number = #interior_job
	for h,v in pairs(interior_job) do
		if not isPointInCircle3D(v[6],v[7],v[8], x,y,z, v[12]) then
			job_count = job_count+1
		end
	end

	if business_count == business_number and house_count == house_number and job_count == job_number then
		local dim = house_number+1

		if inv_player_empty(localPlayer, 25, dim) then
			array_house_1[dim] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
			array_house_2[dim] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
			local house_door = 0

			house_pos[dim] = {x, y, z, createBlip ( x, y, z, 32, 0, 0,0,0,0, 0, 500 ), createPickup ( x, y, z, 3, get("house_icon"), 10000 )}
			setElementData(resourceRoot, "house_pos", house_pos)

			sqlite( "INSERT INTO house_db (number, door, taxation, x, y, z, interior, world, inventory) VALUES ('"..dim.."', '"..house_door.."', '5', '"..x.."', '"..y.."', '"..z.."', '1', '"..dim.."', '106:"..dim..",0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,0:0,')" )

			sendMessage(localPlayer, "Вы получили "..info_png[25][1].." "..dim.." "..info_png[25][2], color_mes.orange)

			inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-get("zakon_price_house"), playername )
		else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Рядом есть бизнес, дом или гос. здание", color_mes.red)
	end
end)

addCommandHandler ( "sellbusiness",--команда для риэлторов
function (localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local business_count = 0
	local house_count = 0
	local job_count = 0
	local id = tonumber(id)

	if logged[playername] == 0 then
		return
	end

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [номер бизнеса от 1 до "..#interior_business.."]", color_mes.red)
		return
	end

	if(search_inv_player_2_parameter(localPlayer, 1) < get("zakon_price_business")) then
	
		sendMessage(localPlayer, "[ОШИБКА] Стоимость бизнеса составляет "..get("zakon_price_business").."$", color_mes.red)
		return
	end

	if id >= 1 and id <= #interior_business then
		if search_inv_player(localPlayer, 45, 1) == 0 then
			sendMessage(localPlayer, "[ОШИБКА] Вы не риэлтор", color_mes.red)
			return
		end

		local result = sqlite( "SELECT COUNT() FROM business_db" )
		local business_number = result[1]["COUNT()"]
		for h,v in pairs(sqlite( "SELECT * FROM business_db" )) do 
			if not isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")*2) then
				business_count = business_count+1
			end
		end

		local result = sqlite( "SELECT COUNT() FROM house_db" )
		local house_number = result[1]["COUNT()"]
		for h,v in pairs(sqlite( "SELECT * FROM house_db" )) do
			if not isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")*2) then
				house_count = house_count+1
			end
		end

		local job_number = #interior_job
		for h,v in pairs(interior_job) do
			if not isPointInCircle3D(v[6],v[7],v[8], x,y,z, v[12]) then
				job_count = job_count+1
			end
		end

		if business_count == business_number and house_count == house_number and job_count == job_number then
			local dim = business_number+1

			if inv_player_empty(localPlayer, 43, dim) then
				business_pos[dim] = {x, y, z, createBlip ( x, y, z, interior_business[id][6], 0, 0,0,0,0, 0, 500 ), createPickup ( x, y, z, 3, get("business_icon"), 10000 )}
				setElementData(resourceRoot, "business_pos", business_pos)

				sqlite( "INSERT INTO business_db (number, type, price, money, taxation, warehouse, x, y, z, interior, world) VALUES ('"..dim.."', '"..interior_business[id][2].."', '0', '0', '5', '0', '"..x.."', '"..y.."', '"..z.."', '"..id.."', '"..dim.."')" )

				sendMessage(localPlayer, "Вы получили "..info_png[43][1].." "..dim.." "..info_png[43][2], color_mes.orange)

				inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-get("zakon_price_business"), playername )
			else
				sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
			end
		else
			sendMessage(localPlayer, "[ОШИБКА] Рядом есть бизнес, дом или гос. здание", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] от 1 до "..#interior_business, color_mes.red)
	end
end)

addCommandHandler ( "buyinthouse",--команда по смене интерьера дома
function (localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local id = tonumber(id)
	local cash = 1000
	local max_interior_house = #interior_house

	if logged[playername] == 0 then
		return
	end

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [номер интерьера от 1 до "..max_interior_house.."]", color_mes.red)
		return
	end

	if id >= 1 and id <= max_interior_house then
		if (cash*id) <= search_inv_player_2_parameter(localPlayer, 1) then
			for h,v in pairs(sqlite( "SELECT * FROM house_db" )) do
				if isPointInCircle3D(v["x"],v["y"],v["z"], x,y,z, get("house_bussiness_radius")) and getElementDimension(localPlayer) == 0 and getElementInterior(localPlayer) == 0 then
					if search_inv_player(localPlayer, 25, v["number"]) ~= 0 then
						sqlite( "UPDATE house_db SET interior = '"..id.."' WHERE number = '"..v["number"].."'")

						inv_server_load( localPlayer, "player", 0, 1, search_inv_player_2_parameter(localPlayer, 1)-(cash*id), playername )

						sendMessage(localPlayer, "Вы изменили интерьер на "..id.." за "..(cash*id).."$", color_mes.orange)
					else
						sendMessage(localPlayer, "[ОШИБКА] У вас нет ключа от дома", color_mes.red)
					end

					return
				end
			end

			sendMessage(localPlayer, "[ОШИБКА] Нужно находиться около дома", color_mes.red)
		else
			sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..(cash*id).."$", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] от 1 до "..max_interior_house, color_mes.red)
	end

end)

addCommandHandler ( "do",
function (localPlayer, cmd, ...)
	local playername = getPlayerName ( localPlayer )
	local text = ""

	if logged[playername] == 0 then
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [текст]", color_mes.red)
		return
	end

	do_chat_player(localPlayer, text.."- "..playername)
end)

addCommandHandler ( "b",
function (localPlayer, cmd, ...)
	local playername = getPlayerName ( localPlayer )
	local text = ""

	if logged[playername] == 0 then
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [текст]", color_mes.red)
		return
	end

	b_chat_player(localPlayer, "(Ближний OOC) "..getPlayerName( localPlayer ).." ["..getElementData(localPlayer, "player_id").."]: "..text)
end)

addCommandHandler ( "try",
function (localPlayer, cmd, ...)
	local playername = getPlayerName ( localPlayer )
	local text = ""

	if logged[playername] == 0 then
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [текст]", color_mes.red)
		return
	end

	try_chat_player(localPlayer, playername.." "..text)
end)

addCommandHandler("capture",--захват территории
function (localPlayer)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local mafia = search_inv_player_2_parameter(localPlayer, 85)

	if (logged[playername] == 0) then
	
		return
	
	elseif(mafia == 0) then
	
		sendMessage(localPlayer, "[ОШИБКА] Вы не состоите в банде", color_mes.red)
		return
	
	elseif(point_guns_zone[1] == 1) then
	
		sendMessage(localPlayer, "[ОШИБКА] Идет захват территории", color_mes.red)
		return

	elseif(crimes[playername] < get("crimes_capture")) then
	
		sendMessage(localPlayer, "[ОШИБКА] Нужно иметь "..get("crimes_capture").." преступлений", color_mes.red)
		return
	end

	local skin = false
	for k,v in pairs(name_mafia[mafia][2]) do
		if v == getElementModel(localPlayer) then
			skin = true
			break
		end
	end

	if not skin then
		sendMessage(localPlayer, "[ОШИБКА] Вы должны быть в одежде своей банды", color_mes.red)
		return
	end

	for k,v in pairs(guns_zone) do
		if (isInsideRadarArea(v[1], x,y) and search_inv_player_2_parameter(localPlayer, 85) ~= v[2]) then
		
			point_guns_zone[1] = 1
			point_guns_zone[2] = k

			point_guns_zone[3] = search_inv_player_2_parameter(localPlayer, 85)
			point_guns_zone[4] = 0

			point_guns_zone[5] = v[2]
			point_guns_zone[6] = 0

			setRadarAreaFlashing ( v[1], true )

			sendMessage(root, "[НОВОСТИ] "..playername.." из "..getTeamName(name_mafia[search_inv_player_2_parameter(localPlayer, 85)][1]).." захватывает территорию - "..getTeamName(name_mafia[v[2]][1]), color_mes.green)
			return
		end
	end
end)

addCommandHandler("cc",--clear chat
function (localPlayer)

	local playername = getPlayerName ( localPlayer )
	if (logged[playername] == 0) then
		return
	end

	clearChatBox(localPlayer)
end)

--------------------------------------------админские команды----------------------------
addCommandHandler ( "sub",--выдача предметов с числом
function (localPlayer, cmd, id, id1, id2 )
	local val1, val2 = tonumber(id1), tonumber(id2)
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not val1 or not val2 then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [ид предмета] [количество]", color_mes.red)
		return
	end

	if val1 > #info_png or val1 < 2 then
		sendMessage(localPlayer, "[ОШИБКА] от 2 до "..#info_png, color_mes.red)
		return
	end

	if val1 == 44 and val2 == get("update_db_rang") and not hasObjectPermissionTo("user."..playername, "command.shutdown") then
		sendMessage(localPlayer, "Вы не основатель", color_mes.red)
		return
	elseif val1 ~= 44 then
		for k,v in pairs(get("no_create_subject")) do
			if (val1 == v) then
				sendMessage(localPlayer, "[ОШИБКА] Этот предмет нельзя создать", color_mes.red)
				return
			end
		end
	end

	local id,player = getPlayerId(id)
		
	if id then
		if inv_player_empty(localPlayer, val1, val2) then
			admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] выдал "..id.." ["..getElementData(player, "player_id").."] "..info_png[val1][1].." "..val2.." "..info_png[val1][2])
		else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "subdel",--удалить предмет
function (localPlayer, cmd, id, id1, id2 )
	local val1, val2 = tonumber(id1), tonumber(id2)
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not val1 or not val2 then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [ид предмета] [количество]", color_mes.red)
		return
	end

	if val1 > #info_png or val1 < 2 then
		sendMessage(localPlayer, "[ОШИБКА] от 2 до "..#info_png, color_mes.red)
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		if inv_player_delet(player, val1, val2, true) then
			admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] удалил у "..id.." ["..getElementData(player, "player_id").."] "..info_png[val1][1].." "..val2.." "..info_png[val1][2])
		else
			sendMessage(localPlayer, "[ОШИБКА] Предмет не найден", color_mes.red)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "subcar",--выдача предметов с числом
function (localPlayer, cmd, id1, id2 )
	local val1, val2 = tonumber(id1), tonumber(id2)
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not val1 or not val2 then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ид предмета] [количество]", color_mes.red)
		return
	end

	if val1 > #info_png or val1 < 2 then
		sendMessage(localPlayer, "[ОШИБКА] от 2 до "..#info_png, color_mes.red)
		return
	end

	for k,v in pairs(get("no_create_subject")) do
		if (val1 == v) then
			sendMessage(localPlayer, "[ОШИБКА] Этот предмет нельзя создать", color_mes.red)
			return
		end
	end

	if not vehicleid then
		sendMessage(localPlayer, "[ОШИБКА] Вы не в т/с", color_mes.red)
		return
	end

	if inv_car_empty(localPlayer, val1, val2, true) then
		admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] создал для "..getVehiclePlateText(vehicleid).." "..info_png[val1][1].." "..val2.." "..info_png[val1][2])
	else
		sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
	end
end)

addCommandHandler ( "subearth",--выдача предметов с числом
function (localPlayer, cmd, id1, id2, count )
	local val1, val2, count = tonumber(id1), tonumber(id2), tonumber(count)
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not val1 or not val2 then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ид предмета] [количество] [количество на земле]", color_mes.red)
		return
	end

	if val1 > #info_png or val1 < 2 then
		sendMessage(localPlayer, "[ОШИБКА] от 2 до "..#info_png, color_mes.red)
		return
	end

	for k,v in pairs(get("no_create_subject")) do
		if (val1 == v) then
			sendMessage(localPlayer, "[ОШИБКА] Этот предмет нельзя создать", color_mes.red)
			return
		end
	end

	for i=1,count do
		max_earth = max_earth+1
		earth[max_earth] = {x,y,z,val1,val2}
	end

	setElementData(resourceRoot, "earth_data", earth)

	admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] создал на земле "..info_png[val1][1].." "..val2.." "..info_png[val1][2].." "..count.." шт")
end)

addCommandHandler ( "go",
function ( localPlayer, cmd, x, y, z )
	local playername = getPlayerName ( localPlayer )
	local x,y,z = tonumber(x), tonumber(y), tonumber(z)
	local vehicleid = getPlayerVehicle(localPlayer)

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if x == nil or y == nil or z == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [и 3 координаты]", color_mes.red)
		return
	end

	if not vehicleid then
		local result = sqlite( "SELECT * FROM account WHERE name = '"..playername.."'" )
		spawnPlayer(localPlayer, x, y, z, 0, result[1]["skin"], getElementInterior(localPlayer), getElementDimension(localPlayer))
	else
		spawnVehicle(vehicleid, x,y,z)
	end
end)

addCommandHandler ( "pos",
function ( localPlayer, cmd, ... )
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local text = ""

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	local result = sqlite( "INSERT INTO position (description, pos) VALUES ('"..text.."', '"..x..","..y..","..z.."')" )
	admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] save pos "..text)
end)

addCommandHandler ( "global",
function ( localPlayer, cmd, ... )
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local text = ""

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	for k,v in ipairs(arg) do
		text = text..v.." "
	end

	if text == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [текст]", color_mes.red)
		return
	end

	sendMessage(root, "[ADMIN] "..playername..": "..text, color_mes.lyme)
end)

addCommandHandler ( "stime",
function ( localPlayer, cmd, id1, id2 )
	local playername = getPlayerName ( localPlayer )
	local house = tonumber(id1)
	local min = tonumber(id2)

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if house == nil or min == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [часов] [минут]", color_mes.red)
		return
	end

	if house >= 0 and house <= 23 and min >= 0 and min <= 59 then
		setTime (house, min)

		admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] stime "..house..":"..min)
	end
end)

addCommandHandler ( "inv",--чекнуть инв-рь игрока
function (localPlayer, cmd, value, id)
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [player | car | house] [имя игрока | номер т/с | номер дома]", color_mes.red)
		return
	end

	if value == "player" then
		local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..id.."'" )
		if result[1]["COUNT()"] == 1 then
			local result = sqlite( "SELECT * FROM account WHERE name = '"..id.."'" )
			local text = ""

			for k,v in pairs(split(result[1]["inventory"], ",")) do
				local spl = split(v, ":")
				text = text..info_png[tonumber(spl[1])][1].." "..spl[2].." "..info_png[tonumber(spl[1])][2].."\n"
			end
			
			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "save", id, text)

			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "load", 0, 0, 0, 0)
		else
			sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
		end

	elseif value == "car" then
		local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..id.."'" )
		if result[1]["COUNT()"] == 1 then
			local result = sqlite( "SELECT * FROM car_db WHERE number = '"..id.."'" )
			local text = ""

			for k,v in pairs(split(result[1]["inventory"], ",")) do
				local spl = split(v, ":")
				text = text..info_png[tonumber(spl[1])][1].." "..spl[2].." "..info_png[tonumber(spl[1])][2].."\n"
			end
			
			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "save", "car-"..id, text)

			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "load", 0, 0, 0, 0)
		else
			sendMessage(localPlayer, "[ОШИБКА] Такого т/с нет", color_mes.red)
		end

	elseif value == "house" then
		local result = sqlite( "SELECT COUNT() FROM house_db WHERE number = '"..id.."'" )
		if result[1]["COUNT()"] == 1 then
			local result = sqlite( "SELECT * FROM house_db WHERE number = '"..id.."'" )
			local text = ""

			for k,v in pairs(split(result[1]["inventory"], ",")) do
				local spl = split(v, ":")
				text = text..info_png[tonumber(spl[1])][1].." "..spl[2].." "..info_png[tonumber(spl[1])][2].."\n"
			end

			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "save", "house-"..id, text)

			triggerClientEvent(localPlayer, "event_invsave_fun", localPlayer, "load", 0, 0, 0, 0)
		else
			sendMessage(localPlayer, "[ОШИБКА] Такого дома нет", color_mes.red)
		end
	end
end)

function prisonplayer (localPlayer, cmd, id, time, ...)--(посадить игрока в тюрьму)
	local playername = getPlayerName ( localPlayer )
	local reason = ""
	local time = tonumber(time)

	for k,v in ipairs(arg) do
		reason = reason..v.." "
	end

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not id or reason == "" or not time then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [время] [причина]", color_mes.red)
		return
	end

	if time < 1 then
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		sendMessage( root, "Администратор "..playername.." посадил в тюрьму "..id.." на "..time.." мин. Причина: "..reason, color_mes.lyme)

		arrest[id] = 2
		inv_server_load (localPlayer, "player", 24, 92, time, playername)
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end
addCommandHandler ( "prisonplayer", prisonplayer)
addEvent("event_prisonplayer", true)
addEventHandler("event_prisonplayer", root, prisonplayer)

function target(localPlayer, cmd, id)
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if not id then
		setCameraTarget(localPlayer, localPlayer)
		return
	end

	local id,player = getPlayerId(id)
		
	if id then
		setCameraTarget(localPlayer, player)

		admin_chat(localPlayer, getPlayerName(localPlayer).." ["..getElementData(localPlayer, "player_id").."] следит за "..id.." ["..getElementData(player, "player_id").."]")
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end
addCommandHandler ( "rc", target)

--[[addCommandHandler ( "banplayer",
function ( localPlayer, cmd, id, ... )
	local playername = getPlayerName ( localPlayer )
	local reason = ""

	for k,v in ipairs(arg) do
		reason = reason..v.." "
	end

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if id == nil or reason == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [причина]", color_mes.red)
		return
	end

	local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..id.."'" )
	if result[1]["COUNT()"] == 1 then

		local result = sqlite( "SELECT * FROM account WHERE name = '"..id.."'" )
		if result[1]["ban"] ~= "0" then
			sendMessage(localPlayer, "[ОШИБКА] Игрок уже забанен", color_mes.red)
			return
		end

		sqlite( "UPDATE account SET ban = '"..reason.."' WHERE name = '"..id.."'")

		sendMessage( root, "Администратор "..playername.." забанил "..id..". Причина: "..reason, color_mes.lyme)

		local id,player = getPlayerId ( id )
		if player then
			kickPlayer(player, "banplayer reason: "..reason)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "unbanplayer",
function ( localPlayer, cmd, id )
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока]", color_mes.red)
		return
	end

	local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..id.."'" )
	if result[1]["COUNT()"] == 1 then

		local result = sqlite( "SELECT * FROM account WHERE name = '"..id.."'" )
		if result[1]["ban"] == "0" then
			sendMessage(localPlayer, "[ОШИБКА] Игрок не забанен", color_mes.red)
			return
		end

		sqlite( "UPDATE account SET ban = '0' WHERE name = '"..id.."'")

		sendMessage( root, "Администратор "..playername.." разбанил "..id, color_mes.lyme)
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)

addCommandHandler ( "banserial",
function ( localPlayer, cmd, id, ... )
	local playername = getPlayerName ( localPlayer )
	local reason = ""

	for k,v in ipairs(arg) do
		reason = reason..v.." "
	end

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if id == nil or reason == "" then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ИД игрока] [причина]", color_mes.red)
		return
	end

	local result = sqlite( "SELECT COUNT() FROM account WHERE name = '"..id.."'" )
	if result[1]["COUNT()"] == 1 then

		local result = sqlite( "SELECT COUNT() FROM banserial_list WHERE name = '"..id.."'" )
		if result[1]["COUNT()"] == 1 then
			sendMessage(localPlayer, "[ОШИБКА] Серийник игрока уже забанен", color_mes.red)
			return
		end

		local result = sqlite( "SELECT * FROM account WHERE name = '"..id.."'" )
		local result = sqlite( "INSERT INTO banserial_list (name, serial, reason) VALUES ('"..id.."', '"..result[1]["reg_serial"].."', '"..reason.."')" )

		sendMessage( root, "Администратор "..playername.." забанил "..id.." по серийнику. Причина: "..reason, color_mes.lyme)

		local id,player = getPlayerId ( id )
		if player then
			kickPlayer(player, "banserial reason: "..reason)
		end
	else
		sendMessage(localPlayer, "[ОШИБКА] Такого игрока нет", color_mes.red)
	end
end)]]

local obj = 0 
addCommandHandler ( "int",
function ( localPlayer, cmd, id0,id1,id2,id3,id4 )
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	local id0,id1,id2,id3,id4 = tonumber(id0),tonumber(id1),tonumber(id2),tonumber(id3),tonumber(id4)
	
	if obj == 0 then
		obj = createObject(id0, x,y,z+id1, id2,id3,id4)
	else
		destroyElement(obj)
		obj = 0
	end
end)

addCommandHandler ( "dim",
function ( localPlayer, cmd, id )
	local playername = getPlayerName ( localPlayer )
	local id = tonumber(id)

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [номер виртуального мира]", color_mes.red)
		return
	end

	setElementDimension ( localPlayer, id )
	sendMessage(localPlayer, "setElementDimension "..id, color_mes.lyme)
end)

addCommandHandler ( "v",--спавн авто для админов
function ( localPlayer, cmd, id )
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	local id = tonumber(id)

	if id == nil then
		sendMessage(localPlayer, "[ОШИБКА] /"..cmd.." [ид т/с]", color_mes.red)
		return
	end

	if id >= 400 and id <= 611 then
		local number = 0

		local val1, val2 = 6, number

		--if inv_player_empty(localPlayer, 6, val2) then
			local x,y,z = getElementPosition( localPlayer )
			local vehicleid = createVehicle(id, x+5, y, z+2, 0, 0, 0, val2)
			local plate = getVehiclePlateText ( vehicleid )

			setElementInterior(vehicleid, getElementInterior(localPlayer))
			setElementDimension(vehicleid, getElementDimension(localPlayer))

			admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] создал т/с")

			--setVehicleDamageProof(vehicleid, true)

			--sendMessage(localPlayer, "Вы получили "..info_png[val1][1].." "..val2.." "..info_png[val1][2], color_mes.lyme)
		--[[else
			sendMessage(localPlayer, "[ОШИБКА] Инвентарь полон", color_mes.red)
		end]]
	else
		sendMessage(localPlayer, "[ОШИБКА] от 400 до 611", color_mes.red)
	end
end)

addCommandHandler ( "delv",--удаление авто для админов
function ( localPlayer )
	local playername = getPlayerName ( localPlayer )

	if logged[playername] == 0 or search_inv_player(localPlayer, 44, 1) == 0 then
		return
	end

	for k,v in pairs(getElementsByType("player")) do
		if getPlayerVehicle(v) and getVehiclePlateText(getPlayerVehicle(v)) == "0" and not isElementFrozen(getPlayerVehicle(v)) then
			removePedFromVehicle(v)
		end
	end

	local count = 0
	for k,v in pairs(getElementsByType("vehicle")) do
		if "0" == getVehiclePlateText(v) and not isElementFrozen(v) then
			destroyElement(v)
			count = count+1
		end
	end

	admin_chat(localPlayer, playername.." ["..getElementData(localPlayer, "player_id").."] удалил "..count.." т/с")
end)
-----------------------------------------------------------------------------------------

function restartAllResources()
	for k,v in pairs(getElementsByType("player")) do
		kickPlayer(v, "restartAllResources")
	end

	-- we store a table of resources
	local allResources = getResources()
	-- for each one of them,
	for index, res in ipairs(allResources) do
		-- if it's running,
		if getResourceState(res) == "running" then
			-- then restart it
			restartResource(res)
		end
	end
end

function input_Console ( text )

	if text == "z" then
		--[[timer = setTimer(function (  )
			for k,v in pairs(getElementsByType("player")) do
				local x,y,z = getElementPosition(v)
				local result = sqlite( "INSERT INTO position (description, pos) VALUES ('job_clear_street6', '"..x..","..y..","..z.."')" )
				sendMessage(root, "save pos "..text, color_mes.lyme)
			end
		end, 5000, 0)

		for i=1,24 do

			sqlite( "INSERT INTO guns_zone (number, x1, y1, x2, y2, mafia) VALUES ('"..(i+24).."', '"..(-3000+((i-1)*250)).."', '-3000', '250', '3500', '0')" )
		end

	elseif text == "c" then
		killTimer(timer)]]

	elseif text == "x" then
		restartAllResources()

	elseif text == "n" then
		pay_taxation()
	end
end
addEventHandler ( "onConsole", root, input_Console )

local objPick = 0
function o_pos( thePlayer )
	local x, y, z = getElementPosition (thePlayer)
	objPick = createObject (322, x, y, z)
	setObjectScale(objPick, 1.7)

	exports["bone_attach"]:attachElementToBone (objPick, thePlayer, 12, 0,0,0, 0,0,0)
end

addCommandHandler ("orot",
function (localPlayer, cmd, id1, id2, id3)
	if objPick ~= 0 then
		setElementBoneRotationOffset (objPick, tonumber(id1), tonumber(id2), tonumber(id3))
	end
end)

addCommandHandler ("opos",
function (localPlayer, cmd, id1, id2, id3)
	if objPick ~= 0 then
		setElementBonePositionOffset (objPick, tonumber(id1), tonumber(id2), tonumber(id3))
	end
end)

addEvent("event_server_attach", true)
addEventHandler ( "event_server_attach", root,
function ( localPlayer, state )
	local playername = getPlayerName ( localPlayer )
	local vehicleid = getPlayerVehicle(localPlayer)

	if vehicleid then
		local x,y,z = getElementPosition(vehicleid)
		if getElementModel(vehicleid) == 548 then
			for k,vehicle in pairs(getElementsByType("vehicle")) do
				local x1,y1,z1 = getElementPosition(vehicle)
				if isPointInCircle3D(x1,y1,z1, x,y,z, 10) then

					if not isElementAttached ( vehicle ) and state == "true" then
						local car_attach = attachElements ( vehicle, vehicleid, 0, 0, -4 )
						if car_attach then
							sendMessage(localPlayer, "т/с прикреплен", color_mes.yellow)
						end
					elseif isElementAttached ( vehicle ) and state == "false" then
						detachElements  ( vehicle, vehicleid )
						sendMessage(localPlayer, "т/с откреплен", color_mes.yellow)
					end

					return
				end
			end
		end
	end
end)

addEvent("event_server_car_door", true)
addEventHandler("event_server_car_door", root,
function ( localPlayer, state )
	local x,y,z = getElementPosition(localPlayer)
	local playername = getPlayerName ( localPlayer )

	for k,vehicle in pairs(getElementsByType("vehicle")) do
		local x1,y1,z1 = getElementPosition(vehicle)
		local plate = getVehiclePlateText ( vehicle )

		if isPointInCircle3D(x,y,z, x1,y1,z1, 10) and search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 then
			if state == "true" then
				setVehicleLocked ( vehicle, true )
				me_chat(localPlayer, playername.." закрыл(а) двери")
			else
				setVehicleLocked ( vehicle, false )
				me_chat(localPlayer, playername.." открыл(а) двери")
			end
			return
		end
	end
end)

addEvent("event_server_car_light", true)
addEventHandler("event_server_car_light", root,
function ( localPlayer, state )
	local x,y,z = getElementPosition(localPlayer)
	local playername = getPlayerName ( localPlayer )

	for k,vehicle in pairs(getElementsByType("vehicle")) do
		local x1,y1,z1 = getElementPosition(vehicle)
		local plate = getVehiclePlateText ( vehicle )

		if isPointInCircle3D(x,y,z, x1,y1,z1, 10) and search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 then
			if state == "true" then
				setVehicleOverrideLights ( vehicle, 2 )
			else
				setVehicleOverrideLights ( vehicle, 1 )
			end
			return
		end
	end
end)

addEvent("event_server_car_engine", true)
addEventHandler ( "event_server_car_engine", root,
function ( localPlayer, state )
	local playername = getPlayerName ( localPlayer )
	local x,y,z = getElementPosition(localPlayer)
	
	for k,vehicleid in pairs(getElementsByType("vehicle")) do
		local x1,y1,z1 = getElementPosition(vehicleid)
		local plate = getVehiclePlateText ( vehicleid )
		local result = sqlite( "SELECT COUNT() FROM car_db WHERE number = '"..plate.."'" )

		if isPointInCircle3D(x,y,z, x1,y1,z1, 10) then
			if result[1]["COUNT()"] == 1 then
				local result = sqlite( "SELECT * FROM car_db WHERE number = '"..plate.."'" )
				if result[1]["taxation"] ~= 0 and search_inv_player(localPlayer, 6, tonumber(plate)) ~= 0 and search_inv_player_2_parameter(localPlayer, 2) == getElementData(localPlayer, "player_id") and fuel[plate] > 0 then
					if state == "true" then
						setVehicleEngineState(vehicleid, true)
						me_chat(localPlayer, playername.." завел(а) двигатель")
					else
						setVehicleEngineState(vehicleid, false)
						me_chat(localPlayer, playername.." заглушил(а) двигатель")
					end
				end
			end

			return
		end
	end
end)

addEvent("event_server_anim_player", true)
addEventHandler("event_server_anim_player", root,
function ( localPlayer, state )
	local x,y,z = getElementPosition(localPlayer)
	local playername = getPlayerName ( localPlayer )
	local spl = split(state, ",")

	if spl[1] ~= "nil" then
		if spl[3] == "true" then
			setPedAnimation(localPlayer, tostring(spl[1]), tostring(spl[2]), -1, true, false, false, false)
		elseif spl[3] == "one" then
			setPedAnimation(localPlayer, tostring(spl[1]), tostring(spl[2]), -1, false, false, false, false)
		elseif spl[3] == "walk" then
			setPedAnimation(localPlayer, tostring(spl[1]), tostring(spl[2]), -1, true, true, false, false)
		elseif spl[3] == "false" then
			setPedAnimation(localPlayer, tostring(spl[1]), tostring(spl[2]), -1, false, false, false, true)
		end
	else
		setPedAnimation(localPlayer, nil, nil)
	end
end)