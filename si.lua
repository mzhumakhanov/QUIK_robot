-- скрипт на таймфрейме отслеживает цену инструмента, на старте таймфрейма покупает, если первое изменение цены рост
-- или продает при падении цены, далее отслеживает цену чтоб не зайти в минус, при достижении цены инструмента равной цене сделки закрывает
-- позицию и ждет следующий таймфрейм, если позиция не закрылась по окончании таймфрейма, фиксируем прибыль ее и все по новой.
----------------------------------------------------------------------------------------
-- Для работы робота необходимо указать текущий торговый счет, а так же код и класс нужного инструмента. Регулировать объем торгов можно количеством
-- лотов в заявке. При запуске скрипт будет ждать начала нового таймфрейма и потом входить в рынок. Прописано два вида таймфреймов получасовой и часовой,
-- которые можно выбрать.
--!!! Для работы скрипта необходимо чтоб для выбранного инструмента был открыт стакан и график !!!
-------------------------- настойки робота ---------------------------------------------
TRADE_ACC   = "4110GNE"           -- торговый счет 
CLASS = "SPBFUT"                  -- код класса инструмента
SEC = "SiH0"					  -- код инструмента GOLD-3.20
lots = 1                          -- количество лотов в заявке
time_frame_type = "H"			  -- таймфрейм H - часовой, M30 - получасовой
work = false                      -- true скрипт работает, false ждет начала нового таймфрейма (для старта скрипта сразу после запуска установить true)
-------------------------- набор переменных --------------------------------------------
last_trans_type = 'N'			  -- тип последней сделки B - купили, S - продали, N - не определен (на старте или после закрытия позиции)	
open_price = 0					  -- цена открытия таймфрейма (последняя цена инструмента на момент открытия)
price = 0						  -- текущая цена инструмента
step = 0						  -- шаг цены 
uniq_trans_id  = 0				  -- id транзакции
dt = ''							  -- серверное время
ds = nil 						  -- объект график
--open_trade = false                -- false утро перед открытием торгов 9:59, потом true
hours = ''							-- час начала таймфрейма
h_serv = nil 						-- час (текущего) серверного времени
h = nil									-- час последней свечи
is_run = true						

function OnStop(s)
  is_run = false
end

function main()
  while is_run do
  	time_frame()														  -- проверяем смену таймфреймов
    sleep(50)
  end
end

function SendOrder(buy_sell, price) 									  --функция выставления заявки
  uniq_trans_id = uniq_trans_id + 1
  local trans = {
          ["ACTION"] = "NEW_ORDER",
          ["CLASSCODE"] = CLASS,
          ["SECCODE"] = SEC,
          ["ACCOUNT"] = TRADE_ACC,
          ["OPERATION"] = buy_sell,
          ["PRICE"] = tostring(price),
          ["QUANTITY"] = tostring(lots),
          ["TRANS_ID"] = tostring(uniq_trans_id)
                }
  local res = sendTransaction(trans)
  write_log("Заявка "..buy_sell.." по цене "..price)
end

function OnTrade(trade)                                                   -- когда сделка состоялась 
	if trade["sec_code"] == SEC then 
		write_log("Сделка по цене "..trade["price"])
		message(" Trade price " .. price, 2)
	end
end

function OnQuote(class_on, sec_on)                                        -- функция отслеживания цены
	if work == true and class_on == CLASS and sec_on == SEC then          -- если скрипт в работе и изменился наш инстумент
	if tonumber(open_price) < 0.000001 or tonumber(hours) ~= ds:T(ds:Size()).hour then return end  -- не работает, если по какой-то причине не задана цена открытия или последняя свеча не текущего часа(открытие торгов)
		if step==0 then step = getSecurityInfo(CLASS, SEC).min_price_step end              -- получаем шаг цены 
		price = getParamEx(CLASS, SEC, "last").param_value                -- получаем цену последней сделки
		if last_trans_type == "N" then                  				  -- если скрипт не работал или начался новый таймфрейм
			if tonumber(open_price) > tonumber(price) then                -- цена упала -> продаем
				message(" sell " .. price, 2)                           
				SendOrder("S",price-10*step)							  -- команда на продажу
				last_trans_type = "S"
			elseif tonumber(open_price) < tonumber(price) then            -- цена выросла -> покупаем
				message(" buy " .. price, 2)                            
				SendOrder("B",price+10*step)							  -- команда на покупку
				last_trans_type = "B"
			end
		elseif last_trans_type == "B" and tonumber(price) < tonumber(open_price) then               
				close_position()										  -- если купили, проверяем чтоб цена не упала ниже чем купили 
		elseif last_trans_type == "S" and tonumber(price) > tonumber(open_price) then                
				close_position() 										  -- если продали, проверяем чтоб цена не выросла выше чем продали
		end
	end
end

function close_position()											 	  -- закрываем позицию
	if last_trans_type == "S" then 
		SendOrder("B",price+10*step)									  -- если продавали -> покупаем	
	elseif last_trans_type == "B" then
		SendOrder("S",price-10*step)									  -- иначе -> продаем
	end
	work = false													  	  -- останавливаемся и ждем новый таймфрейм
	last_trans_type = 'N'
end

function time_frame()                                                    -- проверяем смену таймфреймов
	dt = getInfoParam("SERVERTIME")						  -- получаем время сервера			  
	h_serv = dt:sub(1,2):gsub(":","")							  -- берем час серверного времени, нужно чтоб получить минуты
	if tonumber(h_serv) < 10 then m = dt:sub(3,4) else m = dt:sub(4,5) end -- берем минуты серверного времени
	if time_frame_type == "M30" then ds = CreateDataSource(CLASS, SEC, INTERVAL_M30)  -- получаем набор свечей с указанным интервалом
	elseif time_frame_type == "H" then ds = CreateDataSource(CLASS, SEC, INTERVAL_H1) end
	if ds:Size() == nil then return end									-- если объект график не получен ничего не делаем
	open_price = ds:O(ds:Size())                                          -- берем цену открытия с последней свечи фрейма
	h = ds:T(ds:Size()).hour													-- берем час последней свечи
	if last_trans_type ~= "N" and (m == "59" or (h ==18 and m == "44") or (h == 23 and m == "49")) then 
		write_log("Конец таймфрейма")
		close_position() 												  -- если последняя минута часа или время 18:44 или 23:49 -> закрываем сделку и ждем следующего таймфрейма
	end        
	if time_frame_type == "H" and (tonumber(hours)+1) == tonumber(h) then 	  -- если начался следующий час для часового таймфрейма (hours+1 исключаем начало торгов, когда последняя свеча предыдущего торгового дня h = 23)
		close_position()												  -- закрываем позицию и начинаем работу скрипта
		if tonumber(open_price) < 0.000001 then return end
		hours = h     
		work = true   
		write_log("Начало нового таймфрейма Цена открытия: "..open_price)
		message("new time_frame H = " .. hours .. " open_price " .. open_price, 2)
	elseif time_frame_type == "M30" and ((m == "30" and mins == 0) or (m == "00" and mins == 30)) then
		close_position()												  -- закрываем позицию и начинаем работу скрипта для следующего получаса
		if tonumber(open_price) < 0.000001 then return end
		mins = tonumber(m)
		work = true  
		write_log("Начало нового таймфрейма Цена открытия: "..open_price)
		message("new time_frame M30 = " .. hours .. ":" .. m .. " open_price " .. open_price, 2)
	end 
end

function write_log(log_str)
	dt = getInfoParam("SERVERTIME")										  -- получаем время
	f = io.open(getScriptPath().."\\Log_"..SEC..".txt","a")               -- открываем файл логов
	if f == nill then 													  
		f = io.open(getScriptPath().."\\Log_"..SEC..".txt","w")			  -- если файл не существует -> создаем
	end
	f:write(dt.."  "..log_str.."\n")									  -- пишем лог и закрываем 
	f:flush()
	f:close()
end

function OnInit(s)														  -- инициализация
	write_log("Запуск скрипта")
	hours = dt:sub(1,2):gsub(":","")
 	if tonumber(hours) < 10 then m = dt:sub(3,4) else m = dt:sub(4,5) end
 	if tonumber(m) < 30 then mins = 0 else mins = 30 end
	message("START " .. hours .. ":" .. m .. " " .. time_frame_type .. " SEC " .. SEC, 2)
end
-- Примечание price+/-10*step добавляем к цене в заявке 10 шагов цены для гарантированного исполнения по рынку, 
-- так как при торговле фьючерсами не дает передавать 0 в поле цена для исполнения по рынку как в торговле акциями

