class CommentNotification < ApplicationMailer
  def new_comment(comment, asset)
    @comment = comment[:body]
    @name = comment&.user.name || 'Guest'
    @commenter = person_who_made(comment)
    @song = asset.name
    @number_of_comments = asset.comments_count
    @login = comment.user.login
    @unsubscribe_link = unsubscribe_link
    @settings_link = settings_link(@login)

    mail to: comment.user.email, subject: "[alonetone] Comment on '#{asset.name}' from #{person_who_made(comment)}"
  end

  protected

  def person_who_made(comment)
    comment.commenter ? comment.commenter.name : 'Guest'
  end

  def unsubscribe_link
    'https://' + hostname + '/notifications/unsubscribe'
  end

  def settings_link(user)
    'https://' + hostname + '/' + user + '/edit'
  end
end
