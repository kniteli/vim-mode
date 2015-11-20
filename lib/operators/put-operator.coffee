_ = require 'underscore-plus'
{Operator} = require './general-operators'
settings = require '../settings'

module.exports =
#
# It pastes everything contained within the specifed register
#
class Put extends Operator
  register: null

  constructor: (@editor, @vimState, {@location}={}) ->
    @location ?= 'after'
    @complete = true
    @register = settings.defaultRegister()

  # Public: Pastes the text in the given register. For multiline
  # pastes, it will match up the cursors from previous selection
  # or use the main register for all of them
  #
  # count - The number of times to execute.
  #
  # TODO: How to handle clearing the register stack on deselect
  #
  # Returns nothing.
  execute: (count=1) ->
    {defaultText, type} = @vimState.getRegister(@register) or {};
    @editor.transact 300, () =>
      for cursor, i in @editor.getCursors() then do(cursor, i) =>
        tempRegister = @register
        if(i > 0)
          tempRegister += i
        {text, type} = @vimState.getRegister(tempRegister) or {}
        if(!text)
          text = defaultText
        return unless text

        textToInsert = _.times(count, -> text).join('')
        selection = cursor.selection;
        if selection.isEmpty()
          # Clean up some corner cases on the last line of the file
          if type is 'linewise'
            textToInsert = textToInsert.replace(/\n$/, '')
            if @location is 'after' and @onLastRow()
              textToInsert = "\n#{textToInsert}"
            else
              textToInsert = "#{textToInsert}\n"

          if @location is 'after'
            if type is 'linewise'
              if @onLastRow()
                cursor.moveToEndOfLine()

                originalPosition = cursor.getScreenPosition()
                originalPosition.row += 1
              else
                cursor.moveDown()
            else
              unless @onLastColumn()
                cursor.moveRight()

          if type is 'linewise' and not originalPosition?
            cursor.moveToBeginningOfLine()
            originalPosition = cursor.getScreenPosition()

        selection.insertText(textToInsert)

        if originalPosition?
          cursor.setScreenPosition(originalPosition)
          cursor.moveToFirstCharacterOfLine()

        if type isnt 'linewise'
          cursor.moveLeft()
        @vimState.activateNormalMode()

  # Private: Helper to determine if the editor is currently on the last row.
  #
  # Returns true on the last row and false otherwise.
  onLastRow: ->
    {row, column} = @editor.getCursorBufferPosition()
    row is @editor.getBuffer().getLastRow()

  onLastColumn: ->
    @editor.getLastCursor().isAtEndOfLine()
