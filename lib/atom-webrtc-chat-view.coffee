{$, TextEditorView, View}  = require 'atom-space-pen-views'

module.exports =
class AtomWebrtcChatView extends View
  @content: ->
    @div class: 'atom-webrtc-chat', =>
      @video autoplay: true, muted: true, outlet: 'myVideo'

  initialize: ->

  setMyVideoStream: (stream) ->
    @myVideo.attr 'src', URL.createObjectURL(stream)

  setMyId: (id) ->
    @myVideo.attr 'data-peerid', id
    @myVideo.attr 'poster', @getPosterURL(id)

  getPosterURL: (id) ->
    params = []
    if id?
      params.push "text=" + id
      params.push "fontsize=14"
    params.push "type=" + ((Math.random() * 10) + "")[0]
    "http://dimg.azurewebsites.net/190?" + params.join("&")

  addVideoElement: (id) ->
    video = document.createElement('video')
    video.autoplay = true
    video.setAttribute 'data-id', id
    video.setAttribute 'poster',  @getPosterURL(id)
    @element.appendChild(video)
    return video
