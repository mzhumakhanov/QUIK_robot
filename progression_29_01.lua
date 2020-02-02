-- Входит в рынок по направлению свечи в текущий момент
-- Как только цена прошла цену открытия (свечка поменяла цвет) робот закрывает позицию и открывает ее в противоположную сторону
-------------------------- настойки робота ---------------------------------------------
TRADE_ACC   = "4110GNE"         -- торговый счет 
CLASS = "SPBFUT"                -- код класса инструмента
SEC = "GDH0"					-- код инструмента GOLD-3.20
lots = 1                        -- количество лотов в первой заявке
vid_timframe = "H"				-- вид таймфрейма H - часовой, D - дневной
interval = 0					-- интервал (в минутах) прроверки смены направления свечи, если 0 -> работает всегда
-------------------------- набор переменных --------------------------------------------
buy_sell = "N"					-- вид сделки N - не определен, B - купля, S - продажа
dt = nil						-- серверное время
ds = nil						-- объект график
candle_direction = "N"			-- направление свечи N - не определено, UP - рост(зеленая), DOWN - падение(красная)
candle_direction_pred = "N"		-- предыдущее направление свечи
last_price = 0					-- цена последней сделки
step = 0						-- шаг цены
is_run = true
----------------------------------------------------------------------------------------
 
function OnStop(s)
	is_run = false
end

function main()
	while is_run do
		if interval > 0 then
			Get_candle_direction()							-- определяем текущее направление свечи
			Change_position()								-- меняем позицию, если нужно
			sleep(interval*60000)							-- ждем указанный интервал
		end
		sleep(50)
	end
end

function OnQuote(class_on, sec_on) 							-- следим за изменениями в стакане(срабатывает - значит идут торги)
	if class_on == CLASS and sec_on == SEC and interval == 0 then  -- если изменился наш инстумент и интервал не задан
		Get_candle_direction()								-- определяем текущее направление свечи
		Change_position()									-- меняем позицию, если нужно
	end
end

function Get_candle_direction()								-- определяем направление(цвет) свечи
	candle_direction_pred = candle_direction				-- текущее направление становится предыдущим
	last_price = getParamEx(CLASS, SEC, "last").param_value -- получаем цену последней сделки
	if vid_timframe == "H" then 							-- если смотрим часовые свечи
		ds = CreateDataSource(CLASS, SEC, INTERVAL_H1)
	elseif vid_timframe == "D" then							-- если смотрим дневную свечу
		ds = CreateDataSource(CLASS, SEC, INTERVAL_D1)
	end
	if ds:Size() ~= nil then 
		open_price = ds:O(ds:Size())						-- определяем цену открытия таймфрейма и направление(цвет) свечи
		if tonumber(last_price) < tonumber(open_price) then candle_direction = "DOWN" 
		elseif tonumber(last_price) > tonumber(open_price) then candle_direction = "UP" end
	else return end	
end

function Change_position()									-- сменна позиции, если сменилось направление свечи
	if candle_direction_pred == "N" then					-- не определено предыдущее направление, значит открываем позицию
		Open_position()
		return
	end
	if candle_direction_pred == "DOWN" and candle_direction == "UP" then 		-- смена направления свечи на рост
		SendOrder("B", tonumber(last_price)+10*step) 		-- покупаем, чтоб закрыть позицию
		-- здесь будем менять количество лотов
		SendOrder("B", tonumber(last_price)+10*step) 		-- покупаем, чтобы открыть противоположную позицию
	elseif candle_direction_pred == "UP" and candle_direction == "DOWN" then 	-- смена направления свечи на паадение
		SendOrder("S", tonumber(last_price)+10*step) 		-- продаем, чтоб закрыть позицию
		-- здесь будем менять количество лотов
		SendOrder("S", tonumber(last_price)+10*step) 		-- продаем, чтобы открыть противоположную позицию
	end
end

function Open_position()									-- открытие позиции
	step = getSecurityInfo(CLASS, SEC).min_price_step 		-- получаем шаг цены 
	Get_candle_direction()									-- определяем направление(цвет) свечи
	if candle_direction == "UP" then SendOrder("B", tonumber(last_price)+10*step) -- если растет - покупаем, иначе - продаем
	elseif candle_direction == "DOWN" then SendOrder("S", tonumber(last_price)-10*step) end
	candle_direction_pred = candle_direction
end

function SendOrder(buy_sell, price) 						--функция выставления заявки
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
 -- local res = sendTransaction(trans)
  write_log("Заявка "..buy_sell.." по цене "..price)
end

function write_log(log_str)
	dt = getInfoParam("SERVERTIME")										  			-- получаем время
	f = io.open(getScriptPath().."\\Log_progression"..SEC..".txt","a")              -- открываем файл логов
	if f == nill then 													  
		f = io.open(getScriptPath().."\\Log_progression"..SEC..".txt","w")			-- если файл не существует -> создаем
	end
	f:write(dt.."  "..log_str.."\n")									  			-- пишем лог и закрываем 
	f:flush()
	f:close()
end

function OnInit(s)																	-- инициализация
	write_log("Запуск скрипта")
	--hours = dt:sub(1,2):gsub(":","")
	--if tonumber(hours) > 9 then Open_position()	end						
end
