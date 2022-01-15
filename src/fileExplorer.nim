import nigui

var app* = app
app.init()

var selected*: string

var window* = newWindow()
var mainContainer* = newLayoutContainer(Layout_Vertical)
window.add(mainContainer)

var buttons = newLayoutContainer(Layout_Horizontal)
mainContainer.add(buttons)

var textArea = newTextArea()
mainContainer.add(textArea)

var button1 = newButton("Open ...")
buttons.add(button1)
button1.onClick = proc(event: ClickEvent) =
  var dialog = newOpenFileDialog()
  dialog.title = "Select subtitles file"
  dialog.run()
  if len(dialog.files) > 0: 
    selected = dialog.files[0]
    textArea.addLine(dialog.files[0])
    window.hide()
    app.quit()
  else:
    textArea.addLine("No file selected")
