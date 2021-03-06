(*

  Copyright 2014 Cornell University
  Copyright 2015 Cornell University

  This file is part of VPrl (the Verified Nuprl project).

  VPrl is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  VPrl is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with VPrl.  If not, see <http://www.gnu.org/licenses/>.


  Website: http://nuprl.org/html/verification/
  Authors: Abhishek Anand & Vincent Rahli

*)


Require Import Program.
Require Import Coq.Init.Wf.

Require Export substitution.
Require Export computation1.

(** printing #  $\times$ #×# *)
(** printing <=>  $\Leftrightarrow$ #&hArr;# *)

(** Here, we define the lazy computation system of Nuprl. Since
    it is a deterministic one, we can define it as a (partial)function.
    The computation system of Nuprl is usually specified as a set
    of one step reduction rules. So, our main goal here is to define the
    [compute_step] function. Since a step of computation may result
    in an error, we first lift [NTerm] to add more information
    about the result of one step of computation :

[[

Inductive Comput_Result : Set :=
| csuccess : NTerm -> Comput_Result
| cfailure : String.string-> NTerm -> Comput_Result.

]]

  For a [NonCanonicalOp], we say that some of its arguments are principal.
  Principal arguments are
  subterms that have to be evaluated to a canonical form before checking
  whether the term itself is a redex or not.
  For example, Nuprl's evaluator evaluates the first argument of [NApply]
  until it converges (to a $\lambda$ term).
  The first argument is principal for all [NonCanonicalOp]s.
  For [NCompOp] and [NArithOp], even the second argument is canonical.



    We present the one step computation function in the next page.
    Although it refers to many other definitions, we describe it first so that
    the overall structure of the computation is clear.
    It is defined by pattern matching on the supplied [NTerm].
    If it was a variable, it results in an error.
    If it was an [oterm] with a canonical [Opid], there is nothing more
    to be done. Remember that it is a lazy computation system and a term
    whose outermost [Opid] is canonical is already in normal form.


    If the head [Opid] [ncr] is non-canonical, it does more pattern matching
    to futher expose the structure of its [BTerm]s.
    In particular, the first [BTerm] is principal and
    should have no bound variables and
    its [NTerm] should be an [oterm] (and not a variable).
    If the [Opid] of that [oterm] is canonical, some interesting action can
    be taken. So, there is another (nested) pattern match that invokes
    the appropriate function, depending on the head [Opid] ([ncr]).


    However, if it was non-canonical, the last clause in the top-level
    pattern match gets invoked and it recursively evaluates the first argument
    [arg1nt] and (if the recursive calls succeeds,) repackages
    the result at the same position with the surroundings
    unchanged.


    In the nested pattern match, all but the cases for
    [NCompOp] and [NArithOp] do not need to invoke recursive calls
    of [compute_step]. However, in the cases of [NCompOp] and [NArithOp],
    the first two(instead of one) arguments are principal and need to be
    evaluated first. Hence, the notations [co] and [ca] also take
    [compute_step] as an argument.
    % \pagebreak %


*)


(* begin hide *)

Definition shallow_sub {o} (sub : @Sub o) :=
  forall t, LIn t (range sub) -> size t = 1.

Lemma range_sub_filter_subset {o} :
  forall (sub : @Sub o) l,
    subset (range (sub_filter sub l)) (range sub).
Proof.
  induction sub; introv; simpl; auto.
  destruct a; boolvar; simpl.
  - apply subset_cons1; auto.
  - apply subset_cons2; auto.
Qed.

Lemma simple_size_lsubst_aux {o} :
  forall (t : @NTerm o) sub,
    shallow_sub sub
    -> size (lsubst_aux t sub) = size t.
Proof.
  nterm_ind t as [v|f ind|op bs ind] Case; introv ss; allsimpl; tcsp.

  - Case "vterm".
    remember (sub_find sub v) as sf; symmetry in Heqsf; destruct sf; allsimpl; auto.
    apply sub_find_some in Heqsf.
    apply in_sub_eta in Heqsf; repnd.
    apply ss in Heqsf; auto.

  - Case "oterm".
    f_equal; f_equal; allrw map_map; unfold compose.
    apply eq_maps; introv i; destruct x as [l t]; simpl.
    rw (ind t l); auto.
    intros x j.
    apply (ss x).
    apply range_sub_filter_subset in j; auto.
Qed.

Lemma size_utoken {o} :
  forall a, @size o (mk_utoken a) = 1.
Proof. sp. Qed.

Lemma simple_size_subst_aux {o} :
  forall (t : @NTerm o) v u,
    size u = 1
    -> size (subst_aux t v u) = size t.
Proof.
  introv e.
  unfold subst_aux; apply simple_size_lsubst_aux.
  unfold shallow_sub; simpl; introv k; sp; subst; auto.
Qed.

Lemma simple_size_subst {o} :
  forall (t : @NTerm o) v u,
    size u = 1
    -> size (subst t v u) = size t.
Proof.
  introv e.
  pose proof (unfold_lsubst [(v,u)] t) as h; exrepnd.
  unfold subst; rw h0.
  rw @simple_size_lsubst_aux.
  - apply alpha_eq_preserves_size in h1; auto.
  - unfold shallow_sub; simpl; introv k; sp; subst; auto.
Qed.

Definition size_bs {o} (bs : list (@BTerm o)) :=
  addl (map size_bterm bs).

(* end hide *)


(* We say that the first argument of any non-canonical term
    is a principal argument with respect to computation. It means that
    while evaluating a non-canonical term, its priciple argumens
    must be first evaluated down to a normal form. *)

Definition compute_step_can {o}
           (t : @NTerm o)
           (ncr : NonCanonicalOp)
           (arg1c : CanonicalOp)
           (arg1bts : list BTerm)
           (arg1 : NTerm)
           (btsr : list BTerm)
           (comp : Comput_Result) :=
  match ncr with
    | NApply    => compute_step_apply   arg1c t arg1bts btsr
    | NEApply   => compute_step_eapply btsr t comp arg1 ncr
    | NApseq f  => compute_step_apseq f arg1c t arg1bts btsr
    | NFix      => compute_step_fix     t arg1 btsr
    | NSpread   => compute_step_spread  arg1c t arg1bts btsr
    | NDsup     => compute_step_dsup    arg1c t arg1bts btsr
    | NDecide   => compute_step_decide  arg1c t arg1bts btsr
    | NCbv      => compute_step_cbv     t arg1 btsr
    | NSleep    => compute_step_sleep   arg1c t arg1bts btsr
    | NTUni     => compute_step_tuni    arg1c t arg1bts btsr
    | NMinus    => compute_step_minus   arg1c t arg1bts btsr
    | NFresh    => cfailure "fresh has a bound variable" t
    | NTryCatch      => compute_step_try t arg1 btsr
    | NParallel      => compute_step_parallel arg1c t arg1bts btsr
    | NCompOp    op  => co btsr t arg1bts arg1c op comp arg1 ncr
    | NArithOp   op  => ca btsr t arg1bts arg1c op comp arg1 ncr
    | NCanTest   top => compute_step_can_test top arg1c t arg1bts btsr
  end.

(*
Function compute_step {o}
         (lib : @library o)
         (t : @NTerm o)
         {measure size t} : Comput_Result :=
  match t with
    | vterm v => cfailure compute_step_error_not_closed t
    | oterm (Can _) _ => csuccess t
    | oterm (Mrk _) _ => csuccess t
    | oterm (Exc _) _ => csuccess t
    | oterm (NCan _) [] => cfailure "no args supplied" t
    | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
    | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
      let a := get_fresh_atom lib u in
      compute_step_fresh lib ncan t v vs u bs
                         (@compute_step o lib (subst u v (mk_utoken a)))
                         a
    | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts) :: btsr) =>
      compute_step_can t ncr arg1c arg1bts (oterm (Can arg1c) arg1bts) btsr
                       (match btsr with
                          | bterm _ x :: _ => @compute_step o lib x
                          | _ => cfailure bad_args t
                        end)
    (* assuming qst arg is always principal *)
    (* if the principal argument is an exception, we raise the exception *)
    | oterm (NCan ncr) ((bterm [] (oterm (Exc a) arg1bts))::btsr) =>
      compute_step_catch ncr a t arg1bts btsr
    (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
    | oterm (NCan ncr) ((bterm [] arg1nt)::btsr) =>
      on_success (@compute_step o lib arg1nt) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
    | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
  end.
*)

Definition compute_step_seq_apply {o}
           (t  : @NTerm o)
           (f  : ntseq)
           (bs : list BTerm) :=
  match bs with
    | [bterm [] arg] => csuccess (mk_eapply (mk_ntseq f) arg)
    | _ => cfailure bad_args t
  end.

Definition compute_step_seq_can_test {o}
           (t  : NTerm)
           (bs : list (@BTerm o)) :=
  match bs with
    | [bterm [] _, bterm [] a] => csuccess a
    | _ => cfailure canonical_form_test_not_well_formed t
  end.

Definition compute_step_seq {o}
           (t     : @NTerm o)
           (ncr   : NonCanonicalOp)
           (f     : ntseq)
           (bs    : list (@BTerm o))
           (cstep : Comput_Result) :=
  match ncr with
    | NApply    => compute_step_seq_apply t f bs
    | NEApply   => compute_step_eapply bs t cstep (mk_ntseq f) ncr
    | NApseq _  => cfailure bad_args t
    | NFix      => compute_step_fix t (mk_ntseq f) bs
    | NSpread   => cfailure bad_args t
    | NDsup     => cfailure bad_args t
    | NDecide   => cfailure bad_args t
    | NCbv      => compute_step_cbv t (mk_ntseq f) bs
    | NSleep    => cfailure bad_args t
    | NTUni     => cfailure bad_args t
    | NMinus    => cfailure bad_args t
    | NFresh    => cfailure bad_args t
    | NTryCatch => compute_step_try t (mk_ntseq f) bs
    | NParallel => cfailure bad_args t
    | NCompOp    _ => cfailure bad_args t
    | NArithOp   _ => cfailure bad_args t
    | NCanTest   _ => compute_step_seq_can_test t bs
  end.

(*
(**

  This generates a very complicated term, we'll do that by hand below in
  [compute_step'].

*)
Program Fixpoint compute_step_pf {o}
         (lib : @library o)
         (t : @NTerm o)
         {measure (size t)} : Comput_Result :=
  match t with
    | vterm v => cfailure compute_step_error_not_closed t
    | sterm _ => csuccess t
    | oterm (Can _) _ => csuccess t
    | oterm Exc _ => csuccess t
    | oterm (NCan _) [] => cfailure "no args supplied" t
    | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
    | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
      let a := get_fresh_atom u in
      compute_step_fresh lib ncan t v vs u bs
                         (compute_step_pf lib (subst u v (mk_utoken a)))
                         a
    | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
      compute_step_can t ncr arg1c arg1bts arg1 btsr
                       (match btsr with
                          | bterm _ x :: _ => compute_step_pf lib x
                          | _ => cfailure bad_args t
                        end)
    | oterm (NCan ncr) (bterm [] (sterm f) :: btsr) =>
      compute_step_seq t ncr f btsr
                       (match btsr with
                          | bterm _ x :: _ => compute_step_pf lib x
                          | _ => cfailure bad_args t
                        end)
    (* assuming qst arg is always principal *)
    (* if the principal argument is an exception, we raise the exception *)
    | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
      compute_step_catch ncr t arg1bts btsr
    (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
    | oterm (NCan ncr) ((bterm [] ((oterm _ _) as arg1nt))::btsr) =>
      on_success (compute_step_pf lib arg1nt) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
    | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
  end.

Obligation 1.
{ simpl; rw @simple_size_subst; auto; omega. }
Qed.

Obligation 2.
{ simpl; omega. }
Qed.

Obligation 4.
{ simpl; omega. }
Qed.

Obligation 6.
{ dands; introv; intro k; inversion k. }
Qed.

Obligation 6.
{ dands; introv; intro k; inversion k. }
Qed.

Obligation 7.
{ dands; introv; intro k; inversion k. }
Qed.
*)

(* begin hide *)

(*
Definition compute_step_pf_unfold {o}
         (lib : @library o)
         (t : @NTerm o) : Comput_Result :=
  match t with
    | vterm v => cfailure compute_step_error_not_closed t
    | sterm _ => csuccess t
    | oterm (Can _) _ => csuccess t
    | oterm Exc _ => csuccess t
    | oterm (NCan _) [] => cfailure "no args supplied" t
    | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
    | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
      let a := get_fresh_atom u in
      compute_step_fresh lib ncan t v vs u bs
                         (compute_step_pf lib (subst u v (mk_utoken a)))
                         a
    | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
      compute_step_can t ncr arg1c arg1bts arg1 btsr
                       (match btsr with
                          | bterm _ x :: _ => compute_step_pf lib x
                          | _ => cfailure bad_args t
                        end)
    (* assuming qst arg is always principal *)
    (* if the principal argument is an exception, we raise the exception *)
    | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
      compute_step_catch ncr t arg1bts btsr
    (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
    | oterm (NCan ncr) ((bterm [] arg1nt)::btsr) =>
      on_success (compute_step_pf lib arg1nt) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
    | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
  end.
*)

(*
Lemma compute_step_pf_eq_unfold {o} :
  forall lib (t : @NTerm o),
    compute_step_pf lib t = compute_step_pf_unfold lib t.
Proof.
  destruct t as [v|op bs]; try reflexivity.
  dopid op as [can|ncan|exc|abs] Case; try reflexivity.
  Case "NCan".
  destruct bs; try reflexivity.

  destruct b as [l1 t1].
  destruct l1 as [|v vs].

  - destruct t1 as [v1|op1 bs1]; try reflexivity.

    dopid op1 as [can1|ncan1|exc1|abs1] SCase; try reflexivity.

    + destruct ncan; try reflexivity.

      * destruct bs; try reflexivity.
        simpl; boolvar; try reflexivity.

        { destruct b.
          destruct l; try reflexivity.

          - destruct n as [v2|op2 bs2]; try reflexivity.

            + unfold compute_step_pf.
              unfold compute_step_pf_func.
              unfold Fix_sub.
              simpl.
              boolvar; simpl; tcsp.

            + dopid op2 as [can2|ncan2|exc2|abs2] SSCas2; try reflexivity.

              * unfold compute_step_pf.
                unfold compute_step_pf_func.
                unfold Fix_sub.
                simpl.
                boolvar; tcsp.

              * unfold on_success.
                unfold compute_step_pf at 1.

(*
Check compute_step_func.
Print compute_step_func.
                unfold compute_step_func.
                unfold Fix_sub.
simpl.
rw F_unfold.
t_fold_fix2.
Opaque Fix_F_sub2.
rw fold_fix2.
simpl.


SearchAbout Fix_F_sub.
*)
Abort.
*)

(** Let's now do that by hand using [Fix] *)
Lemma compute_step'_size1 {o} :
  forall ncan v vs (u : @NTerm o) bs a,
    size (subst u v (mk_utoken a)) < size (oterm (NCan ncan) (bterm (v::vs) u :: bs)).
Proof.
  introv.
  rw @simple_size_subst; simpl; try omega.
Qed.

Lemma compute_step'_size2 {o} :
  forall ncr arg1c (arg1bts : list (@BTerm o)) l x bs,
    size x < size (oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts) :: bterm l x :: bs)).
Proof.
  introv; simpl; omega.
Qed.

Lemma compute_step'_size3 {o} :
  forall ncr x (bs : list (@BTerm o)),
    size x < size (oterm (NCan ncr) (bterm [] x :: bs)).
Proof.
  introv; simpl; omega.
Qed.

Lemma compute_step'_size4 {o} :
  forall ncr f l x (bs : list (@BTerm o)),
    size x < size (oterm (NCan ncr) (bterm [] (sterm f) :: bterm l x :: bs)).
Proof.
  introv; simpl; omega.
Qed.

Definition compute_step {o}
           (lib : @library o)
           (t : @NTerm o) : Comput_Result :=
  @Fix NTerm
       (fun a b => lt (size a) (size b))
       (measure_wf lt_wf size)
       (fun _ => Comput_Result)
       (fun t =>
          match t with
            | vterm v => fun _ => cfailure compute_step_error_not_closed t
            | sterm _ => fun _ => csuccess t
            | oterm (Can _) _ => fun _ => csuccess t
            | oterm Exc _ => fun _ => csuccess t
            | oterm (NCan _) [] => fun _ => cfailure "no args supplied" t
            | oterm (NCan nc) (bterm [] (vterm v) :: bs) => fun _ => cfailure compute_step_error_not_closed t
            | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
              fun F =>
                let a := get_fresh_atom u in
                compute_step_fresh
                  lib ncan t v vs u bs
                  (F (subst u v (mk_utoken a))
                     (compute_step'_size1 ncan v vs u bs a))
                  a
            | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
              fun F => compute_step_can t ncr arg1c arg1bts arg1 btsr
                                        ((match btsr with
                                            | bterm l x :: bs => fun F => F x (compute_step'_size2 ncr arg1c arg1bts l x bs)
                                            | _ => fun _ => cfailure bad_args t
                                          end) F)
            | oterm (NCan ncr) (bterm [] (sterm f) :: btsr) =>
              fun F => compute_step_seq t ncr f btsr
                                        ((match btsr with
                                            | bterm l x :: bs => fun F => F x (compute_step'_size4 ncr f l x bs)
                                            | _ => fun _ => cfailure bad_args t
                                          end) F)
            (* assuming qst arg is always principal *)
            (* if the principal argument is an exception, we raise the exception *)
            | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
              fun _ => compute_step_catch ncr t arg1bts btsr
            (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
            | oterm (NCan ncr) ((bterm [] (oterm _ _ as arg1nt))::btsr) =>
              fun F => on_success (F arg1nt (compute_step'_size3 ncr arg1nt btsr)) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
            | oterm (Abs opabs) bs => fun F => compute_step_lib lib opabs bs
          end)
       t.

Definition compute_step_unfold {o}
         (lib : @library o)
         (t : @NTerm o) : Comput_Result :=
  match t with
    | vterm v => cfailure compute_step_error_not_closed t
    | sterm _ => csuccess t
    | oterm (Can _) _ => csuccess t
    | oterm Exc _ => csuccess t
    | oterm (NCan _) [] => cfailure "no args supplied" t
    | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
    | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
      let a := get_fresh_atom u in
      compute_step_fresh lib ncan t v vs u bs
                         (compute_step lib (subst u v (mk_utoken a)))
                         a
    | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
      compute_step_can t ncr arg1c arg1bts arg1 btsr
                       (match btsr with
                          | bterm _ x :: _ => compute_step lib x
                          | _ => cfailure bad_args t
                        end)
    | oterm (NCan ncr) (bterm [] (sterm f) :: btsr) =>
      compute_step_seq t ncr f btsr
                       (match btsr with
                          | bterm _ x :: _ => compute_step lib x
                          | _ => cfailure bad_args t
                        end)
    (* assuming qst arg is always principal *)
    (* if the principal argument is an exception, we raise the exception *)
    | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
      compute_step_catch ncr t arg1bts btsr
    (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
    | oterm (NCan ncr) ((bterm [] arg1nt)::btsr) =>
      on_success (compute_step lib arg1nt) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
    | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
  end.


Lemma compute_step_eq_unfold {o} :
  forall lib (t : @NTerm o),
    compute_step lib t = compute_step_unfold lib t.
Proof.
  destruct t as [v|f|op bs]; simpl; try reflexivity.
  dopid op as [can|ncan|exc|abs] Case; try reflexivity.
  destruct bs as [|b bs]; try reflexivity.
  destruct b as [l t].
  destruct l as [|v vs]; try reflexivity.
  - destruct t as [v1|f1|op1 bs1]; try reflexivity.
    { unfold compute_step at 1.
      destruct bs; try reflexivity;[].
      destruct b.
      destruct ncan; try reflexivity;[].
      destruct l; try reflexivity;[].
      destruct n; try reflexivity;[].
      destruct o0; try reflexivity;[].
      simpl.
      rw Fix_eq; simpl; try reflexivity;[].
      introv F.
      destruct x as [v'|f'|op bs']; auto;[].
      destruct op; auto;[].
      destruct bs'; auto;[].
      destruct b.
      destruct l0.
      - destruct n1; auto.
        + destruct bs'; auto.
          destruct b; auto.
          f_equal; tcsp.
        + destruct o0; try (complete (f_equal; tcsp));[].
          destruct bs'; auto.
          destruct b.
          f_equal; tcsp.
      - f_equal; tcsp.
    }
    dopid op1 as [can1|ncan1|exc1|abs2] SCase; try reflexivity.
    + unfold compute_step at 1.
      destruct bs; try reflexivity.
      destruct b.
      rw Fix_eq; simpl.
      * f_equal.
      * introv F.
        destruct x as [v'|f'|op bs']; auto.
        destruct op; auto.
        destruct bs'; auto.
        destruct b;[].
        destruct l0; auto.
        { destruct n1; auto.
          { destruct bs'; auto.
            destruct b; auto.
            f_equal; tcsp. }
          destruct o0; auto; try (complete (f_equal; tcsp)).
          destruct bs'; auto.
          destruct b; auto.
          apply f_equal; tcsp. }
        { f_equal; tcsp. }
    + unfold compute_step at 1.
      rw Fix_eq; simpl.
      * f_equal.
      * introv F.
        destruct x as [v'|f'|op bs']; auto.
        destruct op; auto.
        destruct bs'; auto.
        destruct b;[].
        destruct l; auto.
        { destruct n0; auto.
          { destruct bs'; auto.
            destruct b.
            f_equal; tcsp. }
          destruct o0; auto; try (complete (f_equal; tcsp)).
          destruct bs'; auto.
          destruct b; auto.
          apply f_equal; tcsp. }
        { f_equal; tcsp. }
  - unfold compute_step at 1.
    rw Fix_eq; simpl.
    + f_equal.
    + introv F.
      destruct x as [v'|f'|op bs']; auto.
      destruct op; auto.
      destruct bs'; auto.
      destruct b;[].
      destruct l; auto.
      { destruct n0; auto.
        { destruct bs'; auto.
          destruct b.
          f_equal; tcsp. }
        destruct o0; auto; try (complete (f_equal; tcsp)).
        destruct bs'; auto.
        destruct b; auto.
        apply f_equal; tcsp. }
      { f_equal; tcsp. }
Qed.

(*
(**

  Let's define this function another way by adding an extra parameter,
  a [nat] that's supposed to be the size of the term

 *)
Fixpoint compute_step'_aux {o}
         (lib : @library o)
         (t : @NTerm o)
         (n : nat) : Comput_Result :=
  match n with
    | 0 => cfailure "" t
    | S n =>
      match t with
        | vterm v => cfailure compute_step_error_not_closed t
        | sterm _ => csuccess t
        | oterm (Can _) _ => csuccess t
        | oterm Exc _ => csuccess t
        | oterm (NCan _) [] => cfailure "no args supplied" t
        | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
        | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
          let a := get_fresh_atom u in
          compute_step_fresh lib ncan t v vs u bs
                             (compute_step'_aux lib (subst u v (mk_utoken a)) (n - size_bs bs))
                             a
        | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
          compute_step_can t ncr arg1c arg1bts arg1 btsr
                           (match btsr with
                              | bterm _ x :: xs => compute_step'_aux lib x (n - (size arg1 + size_bs xs))
                              | _ => cfailure bad_args t
                            end)
        (* assuming qst arg is always principal *)
        (* if the principal argument is an exception, we raise the exception *)
        | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
          compute_step_catch ncr t arg1bts btsr
        (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
        | oterm (NCan ncr) ((bterm [] arg1nt)::btsr) =>
          on_success (compute_step'_aux lib arg1nt (n - size_bs btsr)) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
        | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
      end
  end.

Definition compute_step {o}
         (lib : @library o)
         (t : @NTerm o) : Comput_Result :=
  compute_step_aux lib t (size t).

Definition compute_step_unfold {o}
           (lib : @library o)
           (t : @NTerm o) : Comput_Result :=
  match t with
    | vterm v => cfailure compute_step_error_not_closed t
    | sterm _ => csuccess t
    | oterm (Can _) _ => csuccess t
    | oterm Exc _ => csuccess t
    | oterm (NCan _) [] => cfailure "no args supplied" t
    | oterm (NCan nc) (bterm [] (vterm v) :: bs) => cfailure compute_step_error_not_closed t
    | oterm (NCan ncan) (bterm (v::vs) u :: bs) =>
      let a := get_fresh_atom u in
      compute_step_fresh lib ncan t v vs u bs
                         (compute_step lib (subst u v (mk_utoken a)))
                         a
    | oterm (NCan ncr) (bterm [] (oterm (Can arg1c) arg1bts as arg1) :: btsr) =>
      compute_step_can t ncr arg1c arg1bts arg1 btsr
                       (match btsr with
                          | bterm _ x :: xs => compute_step lib x
                          | _ => cfailure bad_args t
                        end)
    (* assuming qst arg is always principal *)
    (* if the principal argument is an exception, we raise the exception *)
    | oterm (NCan ncr) ((bterm [] (oterm Exc arg1bts))::btsr) =>
      compute_step_catch ncr t arg1bts btsr
    (* if the principal argument is non-canonical or an abstraction then we compute on that term *)
    | oterm (NCan ncr) ((bterm [] arg1nt)::btsr) =>
      on_success (compute_step lib arg1nt) (fun f => oterm (NCan ncr) (bterm [] f :: btsr))
    | oterm (Abs opabs) bs => compute_step_lib lib opabs bs
  end.

Lemma compute_step_eq_unfold {o} :
  forall lib (t : @NTerm o),
    compute_step lib t = compute_step_unfold lib t.
Proof.
  introv.
  destruct t as [v|f|op bs]; try reflexivity.
  destruct op; try reflexivity.
  destruct bs; try reflexivity.
  destruct b.
  destruct l; try reflexivity.
  - destruct n0; try reflexivity.

    { simpl.
      unfold compute_step; simpl.
      fold (size_bs bs).
      assert (match size_bs bs with
                | 0 => S (size_bs bs)
                | S l => size_bs bs - l
              end
              = 1) as e.
      { remember (size_bs bs) as m; clear Heqm.
        destruct m; auto.
        rw <- minus_Sn_m; auto.
        rw minus_diag; auto. }
      rw e; clear e.
      simpl; auto.
    }

    assert (match size_bs bs with
              | 0 => S (addl (map size_bterm l) + size_bs bs)
              | S l0 => addl (map size_bterm l) + size_bs bs - l0
            end
            = S (addl (map size_bterm l))) as e.
    { remember (size_bs bs) as m; clear Heqm.
      destruct m; simpl; try omega. }
    destruct o0; try reflexivity.
    + simpl.
      unfold compute_step; simpl; auto.
      f_equal.
      destruct bs; try reflexivity.
      destruct b; simpl.
      rw plus_permute.
      rw <- NPeano.Nat.add_sub_assoc; auto.
      rw minus_diag.
      rw plus_0_r; auto.
    + simpl.
      unfold compute_step; simpl.
      unfold on_success; simpl.
      allfold (size_bs bs); rw e; simpl; auto.
    + simpl.
      unfold compute_step; simpl.
      allfold (size_bs bs); rw e; simpl; auto.
  - simpl.
    unfold compute_step; simpl.
    allfold (size_bs bs).
    rw <- NPeano.Nat.add_sub_assoc; auto.
    rw minus_diag.
    rw plus_0_r; auto.
    rw @simple_size_subst; simpl; auto.
Qed.
*)

Opaque compute_step.


Tactic Notation "csunf" ident(h) := rewrite @compute_step_eq_unfold in h.
Tactic Notation "csunf" := rewrite @compute_step_eq_unfold.


Lemma compute_step_ncan_ncan {p} :
  forall lib nc nc2 bt2 rest,
    compute_step lib
      (oterm (NCan nc) (bterm [] (oterm (@NCan p nc2) bt2) :: rest))
    = match compute_step lib (oterm (NCan nc2) bt2) with
        | csuccess f => csuccess (oterm (NCan nc) ((bterm [] f) :: rest))
        | cfailure str ts => cfailure str ts
      end.
Proof.
  introv; csunf; simpl; auto.
Qed.

Lemma compute_step_ncan_abs {p} :
  forall lib nc x bt2 rest,
    compute_step lib
      (oterm (NCan nc) (bterm [] (oterm (@Abs p x) bt2) :: rest))
    = match compute_step_lib lib x bt2 with
        | csuccess f => csuccess (oterm (NCan nc) ((bterm [] f) :: rest))
        | cfailure str ts => cfailure str ts
      end.
Proof.
  introv; csunf; simpl; auto.
Qed.

Lemma compute_step_try_ncan {p} :
  forall lib a nc (bts : list (@BTerm p)) v b,
    compute_step lib (mk_try (oterm (NCan nc) bts) a v b)
    = match compute_step lib (oterm (NCan nc) bts) with
        | csuccess f => csuccess (mk_try f a v b)
        | cfailure str ts => cfailure str ts
      end.
Proof.
  introv; csunf; simpl; auto.
Qed.

Lemma compute_step_try_abs {p} :
  forall lib a x (bts : list (@BTerm p)) v b,
    compute_step lib (mk_try (oterm (Abs x) bts) a v b)
    = match compute_step_lib lib x bts with
        | csuccess f => csuccess (mk_try f a v b)
        | cfailure str ts => cfailure str ts
      end.
Proof.
  introv; csunf; simpl; auto.
Qed.


Example comp_test1 {p} :
  forall lib,
    compute_step lib (mk_apply (mk_lam nvarx (vterm nvarx)) (mk_nat 0))
    = csuccess (@mk_nat p 0).
Proof.
  reflexivity.
Qed.

Example comp_test2 {p} :
  forall lib,
    compute_step lib
      (mk_apply
         (mk_apply (mk_lam nvarx (vterm nvarx)) (mk_lam nvarx (vterm nvarx)))
         (mk_nat 0))
    = csuccess (mk_apply (mk_lam nvarx (vterm nvarx)) (@mk_nat p 0)).
Proof.
  reflexivity.
Qed.

(*
Program Fixpoint div2 (n : nat) {measure n} :
  { x : nat | n = 2 * x \/ n = 2 * x + 1 } :=
  match n with
    | S (S p) => S (div2 p)
    | _ => O
   end.
Next Obligation.
  destruct (div2 p (div2_obligation_1 (S (S p)) div2 p eq_refl)).
  repndors; subst; allsimpl; try omega.
Qed.
Next Obligation.
  clear div2.
  induction n; try omega.
  autodimp IHn hyp; tcsp.
  introv k; subst.
  pose proof (H (S p)); sp.
  repndors; subst; tcsp.
  pose proof (H 0); sp.
Qed.

Lemma div2_prop :
  forall n, projT1 (div2 n) <= n.
Proof.
  induction n; simpl; auto.
  destruct n; simpl.
Qed.
*)

Example comp_test_ex_1 {p} :
  forall lib,
    compute_step lib
      (mk_try
         (mk_add (mk_nat 1) (mk_nat 1))
         (mk_token "")
         nvarx
         (mk_var nvarx))
    = csuccess (mk_try
                  (mk_nat 2)
                  (mk_token "")
                  nvarx
                  (@mk_var p nvarx)).
Proof.
  introv; csunf; simpl; auto.
Qed.

Example comp_test_ex3 {p} :
  forall lib,
    compute_step lib
      (mk_try
         (mk_add (mk_nat 1) (mk_exception (mk_token "") mk_zero))
         (mk_token "")
         nvarx
         (mk_var nvarx))
    = csuccess (mk_try
                  (mk_exception (mk_token "")  mk_zero)
                  (mk_token "")
                  nvarx
                  (@mk_var p nvarx)).
Proof.
  introv; csunf; simpl; auto.
Qed.

Definition maybe_compute_step {o} lib (t : @NTerm o) :=
  match compute_step lib t with
    | csuccess x => x
    | cfailure _ _ => t
  end.

Example comp_test_ex4 {p} :
  forall lib,
    on_success
      (compute_step lib
                    (mk_try
                       (mk_exception (mk_token "") mk_zero)
                       (mk_token "")
                       nvarx
                       (mk_var nvarx)))
      (fun x => maybe_compute_step lib x)
    = csuccess (@mk_zero p).
Proof.
  introv; csunf; simpl.
  unfold maybe_compute_step.
  csunf; simpl; unfold co; boolvar; simpl; boolvar; ginv; tcsp.
Qed.

Lemma compute_step_value {p} :
  forall lib t, (@isvalue p t) -> compute_step lib t = csuccess t.
Proof.
  introv h.
  inversion h; subst.
  allapply @iscan_implies; repndors; exrepnd; subst; reflexivity.
Qed.

Lemma compute_step_ovalue {p} :
  forall lib t, @isovalue p t -> compute_step lib t = csuccess t.
Proof.
  introv h.
  inversion h; subst.
  allapply @iscan_implies; repndors; exrepnd; subst; reflexivity.
Qed.

Definition compute_1step {p} lib (t u : @CTerm p) :=
  compute_step lib (get_cterm t) = csuccess (get_cterm u).

(* end hide *)
