{CompositeDisposable} = require 'atom'
{$, TextEditorView, View}  = require 'atom-space-pen-views'

AtomWebrtcChatView = require './atom-webrtc-chat-view'
InputDialogView = require './input-dialog-view'
Peer = require 'peerjs/dist/peer'

module.exports = AtomWebrtcChat =
  config:
    peerId:
      type: 'string'
      default: ''
      order: 1
    useVideo:
      type: 'boolean'
      default: true
      order: 2
    videoSource:
      type: 'integer'
      default: 0
      order: 3
    useAudio:
      type: 'boolean'
      default: true
      order: 4
    audiotSource:
      type: 'integer'
      default: 0
      order: 5
    peerServer:
      type: 'object'
      properties:
        host:
          type: 'string'
          default: 'webrtchat-peer.herokuapp.com'
        port:
          type: 'string'
          default: '443'
        secure:
          type: 'string'
          default: 'true'
        debug:
          type: 'integer'
          default: 3
      order: 6
    stunServer:
      type: 'object'
      properties:
        url:
          type: 'string'
          default: 'stun:stun.l.google.com:19302'
      order: 7
    turnServer1:
      type: 'object'
      properties:
        url:
          type: 'string'
          default: ''
        username:
          type: 'string'
          default: ''
        crediential:
          type: 'string'
          default: ''
      order: 8
    turnServer2:
      type: 'object'
      properties:
        url:
          type: 'string'
          default: ''
        username:
          type: 'string'
          default: ''
        crediential:
          type: 'string'
          default: ''
      order: 9

  atomWebrtcChatView: null
  inputDialogView: null
  rightPanel: null
  modalPanel: null
  subscriptions: null
  peer: null
  peers: {}

  activate: (state) ->
    navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia;

    @atomWebrtcChatView = new AtomWebrtcChatView(state.atomWebrtcChatViewState)
    @inputDialogView = new InputDialogView
    @rightPanel = atom.workspace.addRightPanel(item: @atomWebrtcChatView, visible: false)
    @modalPanel = atom.workspace.addModalPanel(item: @inputDialogView, visible: false)

    # Register command
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:initialize': => @init()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:toggle-view': => @toggleView()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:copy-my-id-to-clipboard', => @clipPeerId()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:call', => @call()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:close', => @close()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:toggle-video', => @toggleVideo()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:toggle-audio', => @toggleAudio()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:send-buffer', => @sendBuffer()

    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:change-video-source', => @changeVideoSource()
    @subscriptions.add atom.commands.add 'atom-workspace', 'atom-webrtc-chat:change-audio-source', => @changeAudioSource()

    @inputDialogView.miniEditor.on 'blur', => @closeInputDialog()
    @subscriptions.add atom.commands.add @inputDialogView.miniEditor.element, 'core:confirm', => @confirm()
    @subscriptions.add atom.commands.add @inputDialogView.miniEditor.element, 'core:cancel', => @closeInputDialog()

    # for debug
    if atom.inDevMode
      console.log atom.config.get('atom-webrtc-chat')

  call: () ->
    @openInputDialog()

  toggleView: () ->
    if @rightPanel.isVisible()
      @rightPanel.hide()
    else
      @rightPanel.show()

  confirm: () ->
    @callPeer @inputDialogView.miniEditor.getText()
    @closeInputDialog()

  openInputDialog: () ->
    return if @modalPanel.isVisible()

    @modalPanel.show()
    @inputDialogView.message.text('Enter a remote Peer ID')
    @inputDialogView.miniEditor.focus()

  closeInputDialog: () ->
    return unless @modalPanel.isVisible()

    @inputDialogView.miniEditor.setText('')
    @modalPanel.hide()

  callPartner: (remotePeerId, stream) ->
    return null unless stream
    call = @peer.call(remotePeerId, stream)
    @bindCallEvent(call)
    return call

  connectPartner: (remotePeerId) ->
    conn = @peer.connect(remotePeerId)
    @bindConnEvent(conn)
    return conn

  bindCallEvent: (call) ->
    call.on 'stream', (stream) =>
      console.log(stream)
      video = @atomWebrtcChatView.addVideoElement(call.peer)
      video.src = URL.createObjectURL(stream)
    call.on 'error', () ->
      console.log("error")
    call.on 'close', () ->

  bindConnEvent: (conn) ->
    conn.on 'open', () =>
      return

    conn.on 'data', (data) =>
      if confirm("Do you receive data?\n from: " + data.peer + "\n file: " + data.uri)
        switch data.type
          when 'buffer'
            editor = atom.workspace.open(data.uri)
            editor.then (editor) ->
              editor.setText(data.text)

  deactivate: ->
    @close()
    @rightPanel.destroy()
    @modalPanel.destroy()
    @atomWebrtcChatView = null
    @InputDialogView = null
    @subscriptions.dispose()

  serialize: ->
    atomWebrtcChatViewState: @atomWebrtcChatView.serialize()

  init: ->
    @initPeer()
    @initLocalStream()
    @rightPanel.show()

  getPeerConfig: ->
    peerConfig = atom.config.get('atom-webrtc-chat.peerServer')
    peerConfig.config = {iceServers: []}
    if atom.config.get('atom-webrtc-chat.stunServer.url', false)
      peerConfig.config.iceServers.push atom.config.get('atom-webrtc-chat.stunServer')
    if atom.config.get('atom-webrtc-chat.turnServer1.url', false)
      peerConfig.config.iceServers.push atom.config.get('atom-webrtc-chat.turnServer1')
    if atom.config.get('atom-webrtc-chat.turnServer2.url', false)
      peerConfig.config.iceServers.push atom.config.get('atom-webrtc-chat.turnServer2')
    console.log peerConfig if atom.inDevMode()
    return peerConfig

  initPeer: ->
    if atom.config.get('atom-webrtc-chat.peerId')?
      @peer = new window.Peer(atom.config.get('atom-webrtc-chat.peerId'), @getPeerConfig())
    else
      @peer = new window.Peer(@getPeerConfig())

    @peer.on 'open', (peerId) =>
      @atomWebrtcChatView.setMyId peerId

    @peer.on 'call', (call) =>
      if @localStream?
        call.answer(@localStream)
      else
        call.answer("")

      @bindCallEvent call
      if @peers[call.peer]?
        @peers[call.peer].call = call
      else
        @peers[call.peer] = { call: call }

    @peer.on 'connection', (conn) =>
      @bindConnEvent conn
      if @peers[conn.peer]?
        @peers[conn.peer].conn = conn
      else
        @peers[conn.peer] = { conn: conn }

    @peer.on 'error', (error) =>
      console.log error
      alert error.message

    @makePeerHeartbeater()

  # events
  initLocalStream: ->
    if @localStream?
      @localStream.stop()
      @localStream = null

    MediaStreamTrack.getSources (sources) =>
      videoSources = @getVideoSources sources
      audioSources = @getAudioSources sources

      videoSource = audioSource = null
      if atom.config.get('atom-webrtc-chat.useVideo') && videoSources.length > 0
        videoSource = videoSources[atom.config.get('atom-webrtc-chat.videoSource')] || videoSources[0]

      if atom.config.get('atom-webrtc-chat.useAudio') && audioSources.length > 0
        audioSource = audioSources[atom.config.get('atom-webrtc-chat.audioSource')] || audioSources[0]

      constraints = {video: false, audio: false}
      if videoSource?
        constraints.video = {optional: [sourceId: videoSource.id]}
      if audioSource?
        constraints.audio = {optional: [sourceId: audioSource.id]}

      console.log constraints
      if !constraints.video && !constraints.audio
        if @localStream?
          @localStream.stop()
          @localStream = null
      else
        navigator.webkitGetUserMedia constraints
          , (stream) =>
            @localStream = stream
            @atomWebrtcChatView.setMyVideoStream @localStream
          , (error) ->
            console.log error

  changeVideoSource: () ->
    MediaStreamTrack.getSources (sources) =>
      videoSources = @getVideoSources sources
      index = (atom.config.get('atom-webrtc-chat.videoSource') || 0 ) + 1
      index = 0 if videoSources.length <= index
      atom.config.set('atom-webrtc-chat.videoSource', index)
      @initLocalStream()
      @reCallPeers()

  changeAudioSource: () ->
    MediaStreamTrack.getSources (sources) =>
      audioSources = @getAudioSources sources
      index = (atom.config.get('atom-webrtc-chat.audioSource') || 0 ) + 1
      index = 0 if audioSources.length <= index
      atom.config.set('atom-webrtc-chat.audioSource', index)
      @initLocalStream()
      @reCallPeers()

  toggleVideo: () ->
    atom.config.set('atom-webrtc-chat.useVideo', !atom.config.get('atom-webrtc-chat.useVideo'))
    @initLocalStream()
    @reCallPeers()

  toggleAudio: () ->
    atom.config.set('atom-webrtc-chat.useAudio', !atom.config.get('atom-webrtc-chat.useAudio'))
    @initLocalStream()
    @reCallPeers()

  getAudioSources: (sources) ->
    source for source in sources when source.kind == 'audio'

  getVideoSources: (sources) ->
    source for source in sources when source.kind == 'video'

  clipPeerId: ->
    atom.clipboard.write @peer.id

  callPeer: (remotePeerId)->
    return unless remotePeerId

    @peers[remotePeerId] = {
      call: @callPartner(remotePeerId, @localStream),
      conn: @connectPartner(remotePeerId)
    }

  reCallPeers: ()->
    console.log(@peers)
    for peerId, peer of @peers
      @callPartner(peerId, @localStream)

  callClose: (remotePeerId) ->
    if remotePeerId?
      if @peers[remotePeerId]?
        @pees[remotePeerId].call?.close?()
        @pees[remotePeerId].conn?.close?()
    else
      for peerId, peer of @peers
        peer.call?.close?()
        peer.conn?.close?()

  close: () ->
    @callClose()
    if @localStream?
      @localStream.stop()
      @localStream = null

  sendBuffer: (remotePeerId) ->
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    uri = atom.project.relativize(editor.getPath())
    text = editor.getBuffer().getText()
    data = {peer: @peer.id,  type: 'buffer', text: text, uri: uri}

    if remotePeerId?
      @pees[remotePeerId]?.conn?.send? data
    else
      for peerId, peer of @peers
        peer.conn?.send? data

  # for peer server on heroku
  makePeerHeartbeater: () ->
    timeoutId = 0
    heartbeat = () =>
      timeoutId = setTimeout =>
        heartbeat()
      , 20000
      if @peer.socket._wsOpen()
        @peer.socket.send {type:'HEARTBEAT'}

    heartbeat()
    return {
        start : () ->
          if timeoutId == 0
            heartbeat()
        stop : () ->
          clearTimeout( timeoutId )
          timeoutId = 0;
      }
