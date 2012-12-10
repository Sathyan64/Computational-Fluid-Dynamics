
!!!    This program sloves Lid Driven Cavity Flow problem using Lattice Boltzmann Method
!!!    Lattice Boltzmann Equation with BGK approximation
!!!    Copyright (C) 2012  Ao Xu
!!!    This work is licensed under the Creative Commons Attribution-NonCommercial 3.0 Unported License.
!!!    Ao Xu, Profiles: <http://www.linkedin.com/pub/ao-xu/30/a72/a29>


!!!                  Moving Wall
!!!               |---------------|
!!!               |               |
!!!               |               |
!!!    Stationary |               | Stationary
!!!       Wall    |               |    Wall
!!!               |               |
!!!               |               |
!!!               |---------------|
!!!                Stationary Wall


        program main
        implicit none
        integer, parameter :: N=129,M=129
        integer :: i, j, itc, itc_max, k
        integer :: iwall(N,M)
        real(8) :: Re, cs2, U_ref, dx, dy, dt, tau
        real(8) :: eps, error
        real(8) :: X(N), Y(M), u(N,M), v(N,M), up(N,M), vp(N,M), rho(N,M), p(N,M), psi(N,M)
        real(8) :: t_k(0:8), f(0:8,N,M), un(0:8)
        real(8) :: xv(0:8), yv(0:8)
        data xv/0.0d0,1.0d0,0.0d0, -1.0d0, 0.0d0, 1.0d0, -1.0d0, -1.0d0, 1.0d0/
        data yv/0.0d0,0.0d0,1.0d0, 0.0d0, -1.0d0, 1.0d0, 1.0d0, -1.0d0, -1.0d0/

!!!     D2Q9 Lattice Vector Properties:
!!!              6   2   5
!!!                \ | /
!!!              3 - 0 - 1
!!!                / | \
!!!              7   4   8

!!! input initial data
        Re = 1000.0d0
        cs2 = 1.0d0/3.0d0
        U_ref = 0.1d0
        dx = 1.0d0/float(N-1)
        dy = 1.0d0/float(M-1)
        dt = dx
        tau = 3.0d0*U_ref/Re/dt+0.5d0
        itc = 0
        itc_max = 5*1e5
        eps = 1e-5
        k = 0
        error = 100.0d0

!!! set up initial flow field
        call initial(N,M,dx,dy,X,Y,u,v,rho,psi,iwall,U_ref,cs2,t_k,xv,yv,un,f)

        do while((error.GT.eps).AND.(itc.LT.itc_max))

!!! streaming step
            call propagate(N,M,f)

!!! collision step
            call relaxation(N,M,iwall,u,v,xv,yv,rho,f,t_k,cs2,tau)

!!! boundary condition
            call bounceback(N,M,f)

!!! check convergence
            call check(N,M,iwall,u,v,up,vp,itc,error)

!!! output preliminary results
            if(MOD(itc,10000).EQ.0) then
                call calp(N,M,cs2,rho,p)
                call calpsi(N,M,dx,dy,up,vp,psi)
                k = k+1
                call output(N,M,X,Y,up,vp,psi,p,k)
            endif

        enddo

!!! compute pressure field
        call calp(N,M,cs2,rho,p)

!!! compute streamfunction
        call calpsi(N,M,dx,dy,up,vp,psi)

!!! output data file
        k = k+1
        call output(N,M,X,Y,up,vp,psi,p,k)

        write(*,*)
        write(*,*) '************************************************************'
        write(*,*) 'This program sloves Lid Driven Cavity Flow problem using Lattice Boltzmann Method'
        write(*,*) 'Lattice Boltzmann Equation with BGK approximation'
        write(*,*) 'Consider D2Q9 Particle Discrete Velocity model'
        write(*,*) 'N =',N,',       M =',M
        write(*,*) 'Re =',Re
        write(*,*) 'eps =',eps
        write(*,*) 'itc =',itc
        write(*,*) '************************************************************'
        write(*,*)

        stop
        end program main

!!! set up initial flow field
        subroutine initial(N,M,dx,dy,X,Y,u,v,rho,psi,iwall,U_ref,cs2,t_k,xv,yv,un,f)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        integer :: iwall(N,M)
        real(8) :: dx, dy
        real(8) :: U_ref, cs2, us2
        real(8) :: X(N), Y(M)
        real(8) :: t_k(0:8), u(N,M), v(N,M), rho(N,M), psi(N,M), xv(0:8), yv(0:8), un(0:8)
        real(8) :: f(0:8,N,M)

        do i=1,N
            X(i) = (i-1)*dx
        enddo
        do j=1,M
            Y(j) = (j-1)*dy
        enddo
        psi = 0.0d0

        t_k(0) = 4.0d0/9.0d0
        do alpha=1,4
            t_k(alpha) = 1.0d0/9.0d0
        enddo
        do alpha=5,8
            t_k(alpha) = 1.0d0/36.0d0
        enddo

        iwall = 0
        u = 0.0d0
        v = 0.0d0
        rho = 1.0d0
        do i=1,N
            u(i,M) = U_ref
        enddo

        !Wall type
        do i=1,N
            iwall(i,1) = 1
            iwall(i,M) = 2
        enddo
        do j=1,M
            iwall(1,j) = 1
            iwall(N,j) = 1
        enddo

        do i=1,N
            do j=1,M
                us2 = u(i,j)*u(i,j)+v(i,j)*v(i,j)
                do alpha=0,8
                    un(alpha) = u(i,j)*xv(alpha)+v(i,j)*yv(alpha)
                    f(alpha,i,j) = t_k(alpha)*(1.0d0+un(alpha)/cs2+un(alpha)*un(alpha)/(2.0d0*cs2*cs2)-us2/(2.0d0*cs2))
                enddo
            enddo
        enddo

        return
        end subroutine initial

!!! streaming step
        subroutine propagate(N,M,f)
        implicit none
        integer :: i, j, N, M
        real(8) :: f(0:8,N,M)

        do i=1,N
            do j=1,M-1
                f(0,i,j) = f(0,i,j)
            enddo
        enddo
        do i=N,2,-1
            do j=1,M-1
                f(1,i,j) = f(1,i-1,j)
            enddo
        enddo
        do i=1,N
            do j=M-1,2,-1
                f(2,i,j) = f(2,i,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=1,M-1
                f(3,i,j) = f(3,i+1,j)
            enddo
        enddo
        do i=1,N
            do j=1,M-1
                f(4,i,j) = f(4,i,j+1)
            enddo
        enddo
        do i=N,2,-1
            do j=M-1,2,-1
                f(5,i,j) = f(5,i-1,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=M-1,2,-1
                f(6,i,j) = f(6,i+1,j-1)
            enddo
        enddo
        do i=1,N-1
            do j=1,M-1
                f(7,i,j) = f(7,i+1,j+1)
            enddo
        enddo
        do i=N,2,-1
            do j=1,M-1
                f(8,i,j) = f(8,i-1,j+1)
            enddo
        enddo

        return
        end subroutine propagate

!!! collision step
        subroutine relaxation(N,M,iwall,u,v,xv,yv,rho,f,t_k,cs2,tau)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        integer :: iwall(N,M)
        real(8) :: cs2, tau
        real(8) :: us2
        real(8) :: u(N,M), v(N,M), xv(0:8), yv(0:8), rho(N,M), f(0:8,N,M), t_k(0:8)
        real(8) :: un(0:8), feq(0:8,N,M)

        do i=1,N
            do j=1,M-1
                if(iwall(i,j).NE.2) then
                    rho(i,j) = 0.0d0
                    do alpha=0,8
                        rho(i,j) = rho(i,j)+f(alpha,i,j)
                    enddo
                    !data xv/0.0d0,1.0d0,0.0d0, -1.0d0, 0.0d0, 1.0d0, -1.0d0, -1.0d0, 1.0d0/
                    !data yv/0.0d0,0.0d0,1.0d0, 0.0d0, -1.0d0, 1.0d0, 1.0d0, -1.0d0, -1.0d0/
                    u(i,j) = (f(1,i,j)-f(3,i,j)+f(5,i,j)-f(6,i,j)-f(7,i,j)+f(8,i,j))/rho(i,j)
                    v(i,j) = (f(2,i,j)-f(4,i,j)+f(5,i,j)+f(6,i,j)-f(7,i,j)-f(8,i,j))/rho(i,j)
                    us2 = u(i,j)*u(i,j)+v(i,j)*v(i,j)
                    do alpha=0,8
                        un(alpha) = u(i,j)*xv(alpha) + v(i,j)*yv(alpha)
                        feq(alpha,i,j) = t_k(alpha)*rho(i,j) &
                                       *(1.0d0+un(alpha)/cs2+un(alpha)*un(alpha)/(2.0d0*cs2*cs2)-us2/(2.0d0*cs2))
                        f(alpha,i,j) = f(alpha,i,j)-1.0d0/tau*(f(alpha,i,j)-feq(alpha,i,j))
                    enddo

                    if((i.EQ.1).AND.(j.EQ.1)) then
                        f(6,i,j) = feq(6,i,j)
                        f(8,i,j) = feq(8,i,j)
                    endif

                    if((i.EQ.N).AND.(j.EQ.1)) then
                        f(5,i,j) = feq(5,i,j)
                        f(7,i,j) = feq(7,i,j)
                    endif

                endif

            enddo
        enddo

        return
        end subroutine relaxation

!!! boundary condition
        subroutine bounceback(N,M,f)
        implicit none
        integer :: N, M, i, j
        real(8) :: f(0:8,N,M)

        do i=1,N
            do j=1,M-1

                !Left side
                if((i.EQ.1).AND.(j.NE.1)) then
                    f(1,i,j) = f(3,i,j)
                    f(5,i,j) = f(7,i,j)
                    f(8,i,j) = f(6,i,j)
                endif

                !Right side
                if((i.EQ.N).AND.(j.NE.1)) then
                    f(3,i,j) = f(1,i,j)
                    f(6,i,j) = f(8,i,j)
                    f(7,i,j) = f(5,i,j)
                endif

                if(j.EQ.1) then
                    !Left-Bottom corner
                    if(i.EQ.1) then
                        f(1,i,j) = f(3,i,j)
                        f(2,i,j) = f(4,i,j)
                        f(5,i,j) = f(7,i,j)
                    !Right-Bottom corner
                    elseif(i.EQ.N) then
                        f(3,i,j) = f(1,i,j)
                        f(6,i,j) = f(8,i,j)
                        f(2,i,j) = f(4,i,j)
                    !Bottom side
                    else
                        f(2,i,j) = f(4,i,j)
                        f(5,i,j) = f(7,i,j)
                        f(6,i,j) = f(8,i,j)
                    endif
                endif

            enddo
        enddo

        return
        end subroutine bounceback

!!! check convergence
        subroutine check(N,M,iwall,u,v,up,vp,itc,error)
        implicit none
        integer :: N, M, i, j
        integer :: alpha
        integer :: itc
        integer :: iwall(N,M)
        real(8) :: error
        real(8) :: u(N,M), v(N,M), up(N,M), vp(N,M)

        itc = itc+1
        error = 0.0d0
        if(itc.EQ.1) error = 10.0d0
        if(itc.EQ.2) error = 10.0d0
        if(itc.EQ.3) error = 10.0d0

        if(itc.GT.3) then
            do i=1,N
                do j=1,M-1
                    if(iwall(i,j).NE.2) then
                        error  = error+SQRT((u(i,j)-up(i,j))*(u(i,j)-up(i,j))+(v(i,j)-vp(i,j))*(v(i,j)-vp(i,j))) &
                                        /SQRT((u(i,j)+0.00001)*(u(i,j)+0.00001)+(v(i,j)+0.00001)*(v(i,j)+0.00001))
                    endif
                enddo
            enddo
        endif

        up = u
        vp = v

        write(*,*) itc,' ',error

!!!        open(unit=01,file='error.dat',status='unknown',position='append')
!!!        if (MOD(itc,2000).EQ.0) then
!!!            write(01,*) itc,' ',error
!!!        endif
!!!        close(01)

        return
        end subroutine check

!!! compute pressure field
        subroutine calp(N,M,cs2,rho,p)
        implicit none
        integer :: N, M, i, j
        real(8) :: cs2
        real(8) :: rho(N,M), p(N,M)

        do i=1,N
            do j=1,M-1
                p(i,j) = rho(i,j)*cs2
            enddo
        enddo

        do i=1,N
            p(i,M) = cs2
        enddo

        return
        end subroutine calp

!!! compute Streamfunction
        subroutine calpsi(N,M,dx,dy,u,v,psi)
        implicit none
        integer :: N, M, i, j
        real(8) :: dx, dy
        real(8) :: u(N,M), v(N,M), psi(N,M)

!        do j=1,M
!            psi(1,j) = 0.0d0
!            psi(N,j) = 0.0d0
!        enddo
!        do i=1,N
!            psi(i,1) = 0.0d0
!            psi(i,M) = 0.0d0
!        enddo

        do i=3,N-2
            do j=2,M-3
            psi(i,j+1) = u(i,j)*2.0d0*dy+psi(i,j-1)
            !psi(i+1,j) = -v(i-1,j)*2.0d0*dx+psi(i-1,j) ! Alternative and equivalent psi formulae
            enddo
        enddo

        do j=2,M-1
            psi(2,j) = 0.25d0*psi(3,j)
            psi(N-1,j) = 0.25d0*psi(N-2,j)
        enddo
        do i=2,N-1
            psi(i,2) = 0.25d0*psi(i,3)
            psi(i,M-1) = 0.25d0*(psi(i,M-2)-0.2d0*dy)
        enddo

        return
        end subroutine calpsi

!!! output data file
        subroutine output(N,M,X,Y,up,vp,psi,p,k)
        implicit none
        integer :: N, M, i, j, k
        real(8) :: X(N), Y(M), up(N,M), vp(N,M), psi(N,M), p(N,M)

        character*16 filename

        filename='0000cavity.dat'
        filename(1:1) = CHAR(ICHAR('0')+MOD(k/1000,10))
        filename(2:2) = CHAR(ICHAR('0')+MOD(k/100,10))
        filename(3:3) = CHAR(ICHAR('0')+MOD(k/10,10))
        filename(4:4) = CHAR(ICHAR('0')+MOD(k,10))

        open(unit=02,file=filename,status='unknown')
        write(02,101)
        write(02,102)
        write(02,103) N, M

        do j=1,M
            do i=1,N
                write(02,100) X(i), Y(j), up(i,j), vp(i,j), psi(i,j), p(i,j)
            enddo
        enddo

100     format(2x,10(e12.6,'      '))
101     format('Title="Lid Driven Cavity Flow"')
102     format('Variables=x,y,u,v,psi,p')
103     format('zone',1x,'i=',1x,i5,2x,'j=',1x,i5,1x,'f=point')

        close(02)

        return
        end subroutine output
