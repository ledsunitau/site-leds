class AddNotificationQueryIndexes < ActiveRecord::Migration[8.1]
  # As duas queries quentes do centro de notificações (a gem só indexa
  # recipient): o badge de não-lidas (roda a cada page load) e a lista ordenada.
  def change
    # badge: WHERE recipient AND read_at IS NULL — índice parcial enxuto
    add_index :noticed_notifications, %i[recipient_type recipient_id],
              where: "read_at IS NULL",
              name: "index_noticed_notifications_unread"
    # lista: WHERE recipient ORDER BY created_at DESC
    add_index :noticed_notifications, %i[recipient_type recipient_id created_at],
              name: "index_noticed_notifications_recipient_created"
  end
end
