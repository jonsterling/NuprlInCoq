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
  Authors: Abhishek Anand & Vincent Rahli & Mark Bickford

*)

Require Export rules_useful.
Require Export subst_tacs_aeq.
Require Export cequiv_tacs.
Require Export per_props_equality.
Require Export sequents_equality.


Definition rule_tyfam_equality {p}
           C
           (a1 a2 b1 b2 : NTerm)
           (x1 x2 y : NVar)
           (i   : nat)
           (H   : @barehypotheses p) :=
  mk_rule
    (mk_baresequent
       H
       (mk_conclax (mk_equality (C a1 x1 b1) (C a2 x2 b2) (mk_uni i))))
    [ mk_baresequent
        H
        (mk_conclax (mk_equality a1 a2 (mk_uni i))),
      mk_baresequent
        (snoc H (mk_hyp y a1))
        (mk_conclax (mk_equality
                       (subst b1 x1 (mk_var y))
                       (subst b2 x2 (mk_var y))
                       (mk_uni i)))
    ]
    [ sarg_var y ].

Lemma rule_tyfam_equality_true {pp} :
  forall lib C Cc (a1 a2 b1 b2 : NTerm),
  forall x1 x2 y : NVar,
  forall i   : nat,
  forall H   : @barehypotheses pp,
(*  forall bc1 : !LIn y (bound_vars b1),
  forall bc2 : !LIn y (bound_vars b2), *)
  forall fvsC : forall a x b, free_vars (C a x b) = free_vars a ++ remove_nvars [x] (free_vars b),
  forall pd  : (forall a x b w s c,
                  {wa : wf_term a
                   & {wb : wf_term b
                   & {ca : cover_vars a s
                   & {cb : cover_vars_upto b (csub_filter s [x]) [x]
                   & lsubstc (C a x b) w s c
                     = Cc (lsubstc a wa s ca) x (lsubstc_vars b wb (csub_filter s [x]) [x] cb)
               }}}}),
  forall eqC : (forall a1 a2 v1 v2 b1 b2 i,
                  equality lib (Cc a1 v1 b1) (Cc a2 v2 b2) (mkc_uni i)
                  <=> (equality lib a1 a2 (mkc_uni i)
                       # (forall a a',
                            equality lib a a' a1
                            -> equality lib (substc a v1 b1) (substc a' v2 b2) (mkc_uni i)))),
    rule_true lib (rule_tyfam_equality
                     C a1 a2 b1 b2
                     x1 x2 y
                     i
                     H).
Proof.
  unfold rule_tyfam_equality, rule_true, closed_type_baresequent, closed_extract_baresequent; simpl.
  intros.

  (* We prove the well-formedness of things *)
  destseq; allsimpl.
  dLin_hyp.
  destruct Hyp as [ ws1 hyp1 ].
  destruct Hyp0 as [ ws2 hyp2 ].
  destseq; allsimpl; proof_irr; GC.

  exists (@covered_axiom pp (nh_vars_hyps H)).

  (* We prove some simple facts on our sequents *)
  assert ((y <> x1 -> !LIn y (free_vars b1))
          # (y <> x2 -> !LIn y (free_vars b2))
          # !LIn y (free_vars a1)
          # !LIn y (free_vars a2)
          # !LIn y (vars_hyps H)) as vhyps.

  {
    clear hyp1 hyp2.
    dwfseq.
    allrw fvsC.
    sp;
      try (complete (generalize (cg0 y); intro p;
                     allrw in_app_iff;
                     allrw in_remove_nvars; allsimpl;
                     autodimp p hyp; tcsp;
                     right; tcsp));
      try (complete (generalize (cg y); intro p;
                     allrw in_app_iff;
                     allrw in_remove_nvars; allsimpl;
                     autodimp p hyp; tcsp;
                     right; tcsp)).
  }

  destruct vhyps as [ nyb1 vhyps ].
  destruct vhyps as [ nyb2 vhyps ].
  destruct vhyps as [ nyA1 vhyps ].
  destruct vhyps as [ nyA2 nyH ].
  (* done with proving these simple facts *)

  vr_seq_true.

  lsubst_tac.
  rewrite @member_eq.
  rw <- @member_equality_iff.

  teq_and_eq (@mk_uni pp i) (C a1 x1 b1) (C a2 x2 b2) s1 s2 H;
    [apply tequality_mkc_uni|].

  pose proof (pd a1 x1 b1 w1 s1 ca1) as e; exrepnd; rw e1; clear e1.
  pose proof (pd a2 x2 b2 w2 s2 cb2) as e; exrepnd; rw e1; clear e1.
  apply eqC.
  dands.

  { (* First, we prove that the a's are types *)
    vr_seq_true in hyp1.
    pose proof (hyp1 s1 s2) as hyp; clear hyp1.
    repeat (autodimp hyp hh).
    exrepnd.
    lsubst_tac.
    rw @member_eq in hyp1.
    rw <- @member_equality_iff in hyp1; auto.
    apply equality_commutes4 in hyp0; auto.
  }

  { (* Then we prove that the b's are type families *)
    intros a a' eqaa'.
    vr_seq_true in hyp2.
    repeat substc_lsubstc_vars3.

    pose proof (hyp2 (snoc s1 (y, a)) (snoc s2 (y, a'))) as h; clear hyp2.
    repeat (autodimp h hyp).

    { (* we have to prove the functionality of our hypotheses *)
      intros s3 sim2.
      inversion sim2; cpx; allsimpl; cpx.
      rw @eq_hyps_snoc; simpl.
      assert (cover_vars a1 s4)
        as cv4
          by (apply (similarity_cover_vars lib) with (hs := H) (s1 := s1); auto).
      exists s1 s4 a t2 w p cv4; sp.
      (* while proving that functionality result, we have to prove that
       * a1 is functional, which we prove using our 1st hyp *)
      vr_seq_true in hyp1.
      generalize (hyp1 s1 s4); thin hyp1; intro hyp1.
      autodimp hyp1 hyp1'.
      autodimp hyp1 hyp1'; exrepnd; clear_irr.
      lift_lsubst in hyp0; lift_lsubst in hyp1.
      rw @member_eq in hyp1.
      rw <- @member_equality_iff in hyp1.
      apply @equality_commutes2 in hyp0; auto.
      allapply @equality_in_uni; auto. }

    { rw @similarity_snoc; simpl.
      exists s1 s2 a a' wa ca; dands; tcsp. }

    exrepnd; clear_irr.
    lsubst_tac.
    rw @member_eq in h1.
    rw <- @member_equality_iff in h1.

    assert (!LIn y (dom_csub s1)) as nys1.
    { allapply @similarity_dom; exrepd; allrw; sp. }

    assert (!LIn y (dom_csub s2)) as nys2.
    { allapply @similarity_dom; exrepd; allrw; sp. }

    assert (cover_vars_upto b1 (csub_filter s2 [x1]) [x1]) as cb12.
    { eapply cover_vars_upto_eq_dom_csub; eauto.
      allapply @similarity_dom; repnd; allrw; auto. }

    assert (cover_vars_upto b2 (csub_filter s1 [x2]) [x2]) as cb21.
    { eapply cover_vars_upto_eq_dom_csub; eauto.
      allapply @similarity_dom; repnd; allrw; auto. }

    assert (cover_vars (mk_var y) (snoc s1 (y, a))) as cov1.
    { apply cover_vars_var.
      repeat (rw @dom_csub_snoc); simpl.
      repeat (rw in_snoc); tcsp. }

    assert (cover_vars (mk_var y) (snoc s2 (y, a'))) as cov2.
    { apply cover_vars_var.
      repeat (rw @dom_csub_snoc); simpl.
      repeat (rw in_snoc); tcsp. }

    apply equality_commutes4 in h0; auto;[].
    clear h1.

    repeat lsubstc_subst_aeq.
    repeat (substc_lsubstc_vars3;[]).
    lsubst_tac.
    repeat lsubstc_snoc2.
    GC; proof_irr; auto.
  }
Qed.


(*
*** Local Variables:
*** coq-load-path: ("." "./close/")
*** End:
*)
