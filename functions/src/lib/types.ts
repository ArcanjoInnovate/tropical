// src/types.ts

export type AcaoTipo =
  | "advertencia"
  | "suspensao"
  | "banimento"
  | "remover_conteudo"
  | "ignorar";

export type DenunciaTipo = "posts" | "stories" | "users" | "chats";

export interface ProcessarDenunciaData {
  denunciaId:       string;
  denunciaTipo:     DenunciaTipo;
  acao:             AcaoTipo;
  motivoAdmin?:     string;
  artigoViolado?:   string;
  suspensaoInicio?: number;
  suspensaoFim?:    number;
}

export interface Denuncia {
  reporter_uid?:     string;
  reporter_id?:      string;
  post_owner_id?:    string;
  story_owner_id?:   string;
  reported_uid?:     string;
  reported_user_id?: string;
  post_id?:          string;
  story_id?:         string;
  chat_id?:          string;
  motivo_label?:     string;
  motivo?:           string;
  artigo?:           string;
  status?:           string;
}

export interface Penalidade {
  protocolo:          string;
  acao:               AcaoTipo;
  motivo:             string;
  motivo_admin:       string;
  artigo_violado:     string;
  aplicada_em:        number;
  aplicada_por:       string;
  denuncia_id:        string;
  denuncia_tipo:      DenunciaTipo;
  tipo?:              string;
  suspensao_inicio?:  number;
  suspensao_fim?:     number;
  conteudo_removido?: string;
  conteudo_tipo?:     string;
  vista?:             boolean;
}

export interface UserSuspenso {
  suspenso?:     boolean;
  suspensao_fim?: number;
}

export interface NotifData {
  recipient_uid: string;
  type:          string;
  title:         string;
  body:          string;
  actor_uid?:    string;
  actor_name?:   string;
  actor_avatar?: string;
  target_id?:    string;
  target_type?:  string;
  created_at:    number;
  read:          boolean;
  count:         number;
  actor_uids:    string[];
}

export interface ProcessarPedidoConviteData {
  pedidoId:        string;
  acao:            "aprovar" | "rejeitar";
  motivoRejeicao?: string;
}