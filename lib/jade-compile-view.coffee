# Inspiration from: https://github.com/adrianlee44/atom-coffee-compile/
# blob/master/lib/coffee-compile-view.coffee

{EditorView} = require 'atom'
_ = require 'underscore-plus'
path = require 'path'
fs = require 'fs'
{allowUnsafeNewFunction} = require 'loophole'
jade = require 'jade'

module.exports =

# Public: Main Jade compile view that extends the {EditorView} prototype.
class JadeCompileView extends EditorView
  # Public: C-tor
  #
  # @editorId     - The Id of a previously allocated editor as {Number}.
  # @sourceEditor - The instance of the source editor.
  #
  # Returns the instanciated object as `JadeCompileView`.
  constructor: ({@sourceEditorId, @sourceEditor}) ->
    super
    if @sourceEditorId? and not @sourceEditor
      @sourceEditor = @getSourceEditor @sourceEditorId
    if @sourceEditor?
      @bindJadeCompileEvents()
    if atom.config.get 'core.useReactEditor'
      # set editor grammar to HTML
      @editor.setGrammar atom.syntax.selectGrammar 'hello.html'

  # Public: Initialize current instance.
  #
  # options - Set options for old editor {Dictionnary}.
  #
  # Returns `undefined`.
  initialize: (options) ->
    # Old EditorView requires mini editor to work properly
    unless atom.config.get 'core.useReactEditor'
      options.mini = true
      super options
      # set editor grammar to HTML
      @editor.setGrammar atom.syntax.selectGrammar("hello.html")
      # mini EditorView doesn't allow changing line height
      # This is used to force line-height changes
      @css 'line-height', atom.config.get('editor.lineHeight') or
        @configDefaults.lineHeight

  # Public: Bind events on Jade compilation
  #
  # Returns `undefined`.
  bindJadeCompileEvents: ->
    if atom.config.get('jade-compile.compileOnSave')
      @subscribe @sourceEditor.buffer, 'saved', => @saveCompiled()
    unless atom.config.get 'core.useReactEditor'
      # Add scrolling to mini EditorView
      @scrollView.on 'mousewheel', (e) =>
        if delta = e.originalEvent.wheelDeltaY
          @scrollTop(@scrollTop() - delta)
          false
      @verticalScrollbar. on 'scroll', =>
        @scrollTop @verticalScrollbar.scrollTop(),
          adjustVerticalScrollbar: false

  # Public: Get current editor instance if exists.
  #
  # id - The Id of the searched editor as {Number}.
  #
  # Returns the instance of the editor as `JadeCompileView`, null otherwise.
  getSourceEditor: (id) ->
    for editor in atom.workspace.getEditors()
      return editor if editor.id?.toString() is id.toString()
    null

  # Public: Get the current code to be previewed.
  #
  # Returns the complete content of the edited code or only the currently
  #  selected text `String`.
  getSelectedCode: ->
    range = @sourceEditor.getSelectedBufferRange()
    code  =
      if range.isEmpty()
        @sourceEditor.getText()
      else
        @sourceEditor.getTextInBufferRange(range)

  # Public: Render code using Jade. Note that the evaluation is done
  # in an internal context (sandboxed) thanks to loophole.
  #
  # code - The code to render as {String}.
  #
  # Returns the rendered HTML as `String`.
  compile: (code) ->
    html = ''
    try
      allowUnsafeNewFunction ->
        html = jade.render code,
          pretty: atom.config.get 'jade-compile.pretty'
          compileDebug: atom.config.get 'jade-compile.compileDebug'
    catch e
      html = e.message
    html

  # Public: Save compiled code.
  #
  # callback - The asynchroneous callback.
  #
  # Returns the callback result if any, `undefined` otherwise.
  saveCompiled: (callback) ->
    try
      text     = @compile @sourceEditor.getText()
      srcPath  = @sourceEditor.getPath()
      srcExt   = path.extname srcPath
      destPath = path.join (path.dirname srcPath),
        "#{path.basename srcPath, srcExt}.html"
      fs.writeFile destPath, text, callback
    catch e
      console.error "jade-compile: #{e.stack}"

  # Public: Render compiled code.
  #
  # Returns `undefined`.
  renderCompiled: ->
    code = @getSelectedCode()
    try
      text = @compile code
    catch e
      text = e.stack
    @getEditor().setText text

  # Public: Update compiled code.
  #
  # Returns the callback result if any, `undefined` otherwise.
  updateDisplay: ->
    # Style cursor to work with new line height
    lineHeight = (atom.config.get 'editor.lineHeight') or
      @configDefaults.lineHeight
    @overlayer.find('.cursor').css 'line-height', lineHeight * 0.8
    super

  # Public: Create a title depending on context usage.
  #
  # Returns the title as `String`.
  getTitle: ->
    if @sourceEditor?
      "Compiled #{@sourceEditor.getTitle()}"
    else
      'Compiled HTML'

  # Public: Get editor's URI.
  #
  # Returns the URI as `String`.
  getUri: -> "jade-compile://editor/#{@sourceEditorId}"
