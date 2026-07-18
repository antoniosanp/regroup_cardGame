package com.regroup.engine;

public class Player {

    private int hp = 30;
    private int pa = 0;
    private int pd = 0;
    private int ma = 0;
    private int md = 0;
    private int cn = 0;
    private int hpp = 0;

    public int hp() {
        return hp;
    }

    public void setHp(int hp) {
        this.hp = hp;
    }

    public int pa() {
        return pa;
    }

    public void setPa(int pa) {
        this.pa = pa;
    }

    public int pd() {
        return pd;
    }

    public void setPd(int pd) {
        this.pd = pd;
    }

    public int ma() {
        return ma;
    }

    public void setMa(int ma) {
        this.ma = ma;
    }

    public int md() {
        return md;
    }

    public void setMd(int md) {
        this.md = md;
    }

    public int cn() {
        return cn;
    }

    public void setCn(int cn) {
        this.cn = Math.min(cn, 2);
    }

    public int hpp() {
        return hpp;
    }

    public void setHpp(int hpp) {
        this.hpp = hpp;
    }
}
