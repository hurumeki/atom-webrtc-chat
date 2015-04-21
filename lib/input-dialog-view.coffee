{$, TextEditorView, View}  = require 'atom-space-pen-views'

module.exports =
class InputDialogView extends View
  @content: ->
    @div class: 'webrtc-chat-dialog', =>
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'message', outlet: 'message'

  initialize: ->
    @miniEditor.getModel().onWillInsertText ({cancel, text}) =>
      cancel() unless text.match(/[0-9a-zA-Z:]/)
