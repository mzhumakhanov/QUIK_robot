# QUIK_robot
 торговый робот Si
 скрипт на таймфрейме отслеживает цену инструмента, на старте таймфрейма покупает, если первое изменение цены рост или продает при падении цены, далее отслеживает цену чтоб не зайти в минус, при достижении цены инструмента равной цене сделки закрывает позицию и ждет следующий таймфрейм, если позиция не закрылась по окончании таймфрейма, фиксируем прибыль ее и все по новой.
 
 Второй робот прогрессия
  Входит в рынок по направлению свечи в текущий момент, как только цена прошла цену открытия (свечка поменяла цвет) робот закрывает позицию и открывает ее в противоположную сторону