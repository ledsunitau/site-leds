# RF-ADM-03: gestão dos perfis de membro (vínculo com a conta, bio, foto,
# padrinho e a tag de fundador — RN-04).
class Admin::MembersController < Admin::BaseController
  def create
    authorize Member
    member = Member.create!(member_params)
    render json: member_json(member), status: :created
  end

  def update
    member = Member.find(params[:id])
    authorize member
    member.update!(member_params)
    render json: member_json(member)
  end

  def destroy
    member = Member.find(params[:id])
    authorize member
    member.destroy!
    head :no_content
  end

  private

  def member_params
    params.expect(member: [ :user_id, :bio, :founder, :padrinho_id, :foto ])
  end

  def member_json(member)
    {
      id: member.id,
      user_id: member.user_id,
      name: member.name,
      bio: member.bio,
      founder: member.founder,
      padrinho_id: member.padrinho_id
    }
  end
end
