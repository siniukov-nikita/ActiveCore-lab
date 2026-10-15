# Показ лабораторной на Windows: Nexys4-DDR, Vivado и Python

Эта инструкция описывает показ одной прошивки, в которой доступны вариант 3
(деление на 17) и вариант 10 (CORDIC `atan2`). Номер COM-порта не является
частью проекта: на каждом компьютере его нужно определить заново и передать
скрипту параметром.

## 1. Что делает каждая программа

Есть два разных соединения с платой:

1. **Vivado Hardware Manager и JTAG** — загружает `.bit` в FPGA.
2. **Python и UDM через USB-UART** — после прошивки отправляет команды чтения и
   записи в регистры ускорителя.

Python не прошивает FPGA. Вызов `udm.check()` отправляет запрос и ждет ответ
UDM. Если запустить Python до загрузки bitstream, ответ не придет и программа
будет выглядеть как зависшая. Это не этап отладки алгоритма; остановите такой
запуск `Ctrl+C`, сначала прошейте плату, затем повторите тест.

## 2. Подготовка Windows

Установите:

- Vivado Design Suite 2019.1 WebPACK или установленную в вашей лаборатории
  версию;
- Python 3 или WinPython;
- пакет `pyserial`.

В PowerShell из корня репозитория можно создать отдельное окружение:

```powershell
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install pyserial
```

Если PowerShell запрещает запуск `Activate.ps1`, можно не активировать
окружение, а запускать его интерпретатор напрямую:

```powershell
.\.venv\Scripts\python.exe -m pip install pyserial
.\.venv\Scripts\python.exe designs\rtl\udm\sw\divider_test.py --help
```

В PyCharm выберите `File -> Open` и откройте **корень репозитория**, а не только
папку `sw`. В `Settings -> Project -> Python Interpreter` выберите
`.venv\Scripts\python.exe`.

## 3. Определение COM-порта

1. Подключите Nexys4-DDR кабелем USB.
2. Откройте `Диспетчер устройств` (`devmgmt.msc`).
3. Раскройте `Порты (COM и LPT)`.
4. Запомните номер порта платы, например `COM5`.
5. Если список изменился после отключения кабеля, используйте новый номер.

Не редактируйте `udm.py` и не заменяйте в нем `COM1`: тестовый скрипт принимает
порт параметром. Если найден ровно один последовательный порт, он выбирается
автоматически; при нескольких портах укажите его явно:

```powershell
python designs\rtl\udm\sw\divider_test.py --port COM5 --variant 3
```

COM-порт может быть занят открытым Serial Monitor, другой копией Python,
PuTTY или терминалом. Перед тестом закройте такие программы.

## 4. Открытие проекта Vivado

1. Запустите **Vivado 2019.1**.
2. Нажмите `Open Project`.
3. Откройте файл:

   ```text
   designs\rtl\udm\syn\NEXYS4_DDR\NEXYS4_DDR.xpr
   ```

4. В панели `Sources` проверьте:
   - `Design Sources` содержит `NEXYS4_DDR`;
   - подключены `const_divider.v` и `atan2_cordic.v`;
   - `Constraints` содержит `NEXYS4_DDR.xdc`.

### Что означает `Set as Top`

`Set as Top` — это выбор верхнего HDL-модуля, который Vivado считает корнем
сборки. Это **не** превращает Python-файл в исполняемый и не относится к COM.

- Для прошивки в `Design Sources` верхним модулем должен быть
  `NEXYS4_DDR`.
- Для RTL-симуляции верхним модулем simulation set должен быть `tb`, если
  запускается интеграционный testbench.

Если Vivado выбрал другой модуль: в `Sources` нажмите правой кнопкой на
`NEXYS4_DDR` -> `Set as Top`. Для simulation set нажмите правой кнопкой на
`tb` -> `Set as Top` именно в разделе `Simulation Sources`.

Обычно в поставленном `.xpr` эти top-модули уже указаны; `Set as Top` нужен,
если вы случайно изменили выбор или добавили новый файл.

## 5. Сборка bitstream кнопками Vivado

Вариант через графический интерфейс:

1. В Flow Navigator слева нажмите `Run Synthesis`.
2. После завершения нажмите `Run Implementation`.
3. Нажмите `Generate Bitstream`.
4. На вопрос о запуске отсутствующих шагов согласитесь (`Yes`).
5. Дождитесь сообщения `Bitstream Generation Completed`.

Вариант через подготовленный Tcl-скрипт:

1. Откройте `Tools -> Run Tcl Script`.
2. Выберите:

   ```text
   designs\rtl\udm\syn\NEXYS4_DDR\build_windows.tcl
   ```

   Либо выполните в Tcl Console:

   ```tcl
   source [file join [file dirname [get_property DIRECTORY [current_project]]] build_windows.tcl]
   ```

Скрипт использует путь относительно самого себя, поэтому репозиторий можно
положить в другую папку или на другой диск Windows. Результат обычно находится
в каталоге:

```text
designs\rtl\udm\syn\NEXYS4_DDR\NEXYS4_DDR.runs\impl_1\NEXYS4_DDR.bit
```

## 6. Прошивка FPGA через Hardware Manager

Правильный порядок перед Python-тестом:

1. Подключите плату к USB.
2. В Vivado откройте `Flow Navigator -> Hardware Manager`.
3. Нажмите `Open Target -> Auto Connect`.
4. В окне `Hardware` должна появиться FPGA, обычно `xc7a100t`.
5. Нажмите правой кнопкой на FPGA -> `Program Device`.
6. В поле `Bitstream file` выберите сгенерированный
   `NEXYS4_DDR.bit`.
7. Нажмите `Program`.
8. Дождитесь сообщения об успешном программировании.

После этого не запускайте новый bitstream и не закрывайте USB-подключение до
завершения Python-теста. JTAG-программатор и COM-порт могут отображаться как
разные устройства, это нормально.

## 7. Запуск теста из PyCharm

Удобнее создать конфигурацию `Run/Debug Configuration`:

1. `Run -> Edit Configurations`.
2. `+ -> Python`.
3. `Script path`:

   ```text
   <repo>\designs\rtl\udm\sw\divider_test.py
   ```

4. `Python interpreter`: `<repo>\.venv\Scripts\python.exe`.
5. `Working directory`: `<repo>`.
6. В `Parameters` укажите, например:

   ```text
   --port COM5 --variant 3
   ```

7. Нажмите `Apply`, затем `Run`.

То же из PowerShell:

```powershell
python designs\rtl\udm\sw\divider_test.py --port COM5 --variant 3
```

Если на компьютере подключен только один подходящий COM-порт, `--port` можно
опустить:

```powershell
python designs\rtl\udm\sw\divider_test.py --variant 3
```

## 8. Демонстрация варианта 3

После успешной прошивки:

```powershell
python designs\rtl\udm\sw\divider_test.py `
  --port COM5 `
  --variant 3 `
  --values 0 1 16 17 18 34 65535
```

Ожидаемые ключевые результаты:

```text
x=    0 quotient=    0 remainder= 0 ... PASS
x=   17 quotient=    1 remainder= 0 ... PASS
x=65535 quotient= 3855 remainder= 0 ... PASS
```

Адреса UDM:

| Адрес | Назначение |
|---|---|
| `0x00000008` | выбор режима: `0` |
| `0x00000010` | 16-битный аргумент `x` |
| `0x00000014` | частное |
| `0x00000018` | остаток |

## 9. Переключение и демонстрация варианта 10

Перепрошивать FPGA не нужно. Скрипт сам записывает `VARIANT_SEL=1`:

```powershell
python designs\rtl\udm\sw\divider_test.py `
  --port COM5 `
  --variant 10 `
  --values 0 1 -1 100 -100
```

Для варианта 10 текущий демонстрационный скрипт использует каждое значение
как `y`, а `x=1`. Результат выводится как signed Q3.29. Для чтения и записи
общей карты:

| Адрес | Вариант 10 |
|---|---|
| `0x00000008` | выбор режима `1` |
| `0x00000010` | `y` |
| `0x00000014` | `x` |
| `0x00000018` | `atan2(y,x)` |

Например, Q3.29 означает, что радианы хранятся как целое, умноженное на
`2^29`. Чтобы перевести положительное значение `angle` в радианы, разделите
его на `536870912`.

## 10. Если тест «завис»

### Python завис на `Connecting COM port...` или `check()`

1. Остановите `Ctrl+C`.
2. Проверьте, что FPGA уже запрограммирована через `Program Device`.
3. Проверьте COM в Device Manager.
4. Закройте другие программы, использующие порт.
5. Повторите команду с явным `--port COMx`.

### `No serial ports found`

Переподключите USB, установите драйвер платы/кабеля и снова откройте Device
Manager. Номер COM появляется только после обнаружения устройства Windows.

### `Multiple serial ports found`

Укажите порт явно. Не выбирайте автоматически первый порт из списка:

```powershell
python designs\rtl\udm\sw\divider_test.py --port COM5 --variant 3
```

### `Access is denied` или `PermissionError`

Порт занят другим процессом. Закройте Serial Monitor, PuTTY, предыдущий
запуск PyCharm и терминалы, затем повторите.

### Vivado не видит FPGA

Проверьте USB-кабель JTAG, питание платы и `Hardware Manager -> Open Target ->
Auto Connect`. COM-порт сам по себе не означает, что JTAG-программатор
подключен и FPGA прошита.

### Vivado сообщает ошибку top-модуля

В `Sources` выберите `NEXYS4_DDR`, нажмите правой кнопкой
`Set as Top`, затем повторите synthesis. Для симуляции отдельно выберите
`tb` в `Simulation Sources`.

### `No module named serial`

Выбран не тот Python-интерпретатор. В терминале PyCharm выполните:

```powershell
python -m pip install pyserial
python -c "import serial; print(serial.__version__)"
```

## Короткий алгоритм показа

1. Подключить плату и узнать `COMx` в Device Manager.
2. Открыть `.xpr` в Vivado.
3. Проверить `NEXYS4_DDR` через `Set as Top`.
4. Выполнить synthesis/implementation/bitstream.
5. `Hardware Manager -> Auto Connect -> Program Device`.
6. Только теперь запустить Python с `--port COMx --variant 3`.
7. Показать результаты деления.
8. Запустить тот же скрипт с `--variant 10`, не перепрошивая FPGA.
9. При проблеме остановить Python, проверить JTAG и COM отдельно, затем
   повторить тест.
