app = require 'application'
BaseView = require 'lib/base_view'
Gallery = require 'views/gallery'
{editable} = require 'lib/helpers'
contactModel = require 'models/contact'
Contact = new contactModel()

module.exports = class AlbumView extends BaseView
    template: require 'templates/album'

    id: 'album'
    className: 'container-fluid'

    events: =>
        'click   a.delete' : @destroyModel
        'click   a.changeclearance' : @changeClearance
        'click   a.addcontact' : @addcontact
        'click   a.sendmail' : @sendMail
        'click   a.add' : @prepareContact

    getRenderData: ->
        clearanceHelpers = @clearanceHelpers(@model.get 'clearance')
        _.extend {clearanceHelpers: clearanceHelpers}, @model.attributes

    afterRender: ->
        @gallery = new Gallery
            el: @$ '#photos'
            editable: @options.editable
            collection: @model.photos
            beforeUpload: @beforePhotoUpload

        @gallery.render()

        @makeEditable() if @options.editable

    # save album before photos are uploaded to it
    # store albumid in the photo
    beforePhotoUpload: (callback) =>
        @saveModel().then =>
            callback albumid: @model.id

    # make the divs editable
    makeEditable: =>
        @$el.addClass 'editing'

        @refreshPopOver @model.get 'clearance'

        editable @$('#title'),
            placeholder: 'Title ...'
            onChanged: (text) => @saveModel title: text

        editable @$('#description'),
            placeholder: 'Write some more ...'
            onChanged: (text) => @saveModel description: text

    destroyModel: ->
        if @model.isNew()
            return app.router.navigate 'albums', true

        if confirm 'Are you sure ?'
            @model.destroy().then ->
                app.router.navigate 'albums', true

    changeClearance: (event) ->
        newclearance = event.target.id.replace 'change', ''

        @saveModel(clearance: newclearance).then =>
            @refreshPopOver newclearance

    refreshPopOver: (clearance) ->
        help =  @clearanceHelpers clearance
        modal = @$('#clearance-modal')

        @$('.clearance').find('span').text clearance
        modal.find('h3').text help.title
        modal.find('.modal-body').html help.content
        modal.find('.changeclearance').show()
        modal.find('#change' + clearance).hide()
        console.log clearance
        if clearance is "hidden"
            modal.find('.share').show()
        else
            console.log "hide"
            modal.find('.share').hide()

    addcontact: () ->
        # Initialize user's contacts
        modal = @$('#add-contact-modal')
        @options.contacts = []
        Contact.list
            success: (body) =>
                for contact in body
                    for item in contact.datapoints
                        if item.name is "email"
                            @options.contacts.push contact
                            break

                @render modal
                @$('#add-contact-modal').modal('show')
            error: (err) ->
                console.log err

    prepareContact: (event) ->
        # Recover mails of selected contacts
        modal = @$('#add-contact-modal')
        mails = []
        for contact in @options.contacts 
            if @$("##{contact.fn}").is(':checked')
                for item in contact.datapoints
                    if item.name is "email"
                        mails.push item.value
        @$('#mails').val(mails)

    sendMail: () ->
        @model.sendMail @getPublicUrl(), @$('#mails').val(), 
            error: (err) ->
                alert JSON.stringify(err.responseText)

    saveModel: (hash) ->
        promise = @model.save(hash)
        if @model.isNew()
            promise = promise.then =>
                app.albums.add @model
                app.router.navigate "albums/#{@model.id}/edit"

        return promise

    getPublicUrl: ->
        origin = window.location.origin
        path = window.location.pathname.replace 'apps', 'public'
        path = '/public/' if path is '/'
        hash = window.location.hash.replace '/edit', ''
        return origin + path + hash

    clearanceHelpers: (clearance) ->
        if clearance is 'public'
            title: 'This album is public',
            content: 'It will appears on your homepage.'
        else if clearance is 'hidden'
            title: 'This album is hidden',
            content: "It will not appears on your homepage.
                But you can share it with the following url :
                #{ @getPublicUrl() }"
        else if clearance is 'private'
            title: 'This album is private',
            content: 'It cannot be accessed from the public side'
