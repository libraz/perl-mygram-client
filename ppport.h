/* ppport.h -- Perl/Pollution/Portability Version 3.68
 *
 * Simplified version for MygramDB::Client::XS
 */

#ifndef _PPPORT_H_
#define _PPPORT_H_

#ifndef PERL_REVISION
#  if !defined(__PATCHLEVEL_H_INCLUDED__) && !(defined(PATCHLEVEL) && defined(SUBVERSION))
#    define PERL_REVISION       5
#    define PERL_VERSION        PATCHLEVEL
#    define PERL_SUBVERSION     SUBVERSION
#  endif
#endif

#ifndef pTHX
#  define pTHX                  void
#  define pTHX_
#  define aTHX
#  define aTHX_
#endif

#ifndef dTHX
#  define dTHX                  dNOOP
#endif

#ifndef dNOOP
#  define dNOOP                 extern int Perl___notused(void)
#endif

#ifndef NVTYPE
#  define NVTYPE                double
#endif

#ifndef INT2PTR
#  define INT2PTR(any,d)        (any)(d)
#endif

#ifndef PTR2IV
#  define PTR2IV(p)             INT2PTR(IV,p)
#endif

#ifndef newSVuv
#  define newSVuv(u)            ((u) <= IV_MAX ? newSViv((IV)(u)) : newSVnv((NV)(u)))
#endif

#ifndef SvPV_nolen
#  define SvPV_nolen(sv)        SvPV(sv, PL_na)
#endif

#ifndef Newx
#  define Newx(v,n,t)           New(0,v,n,t)
#endif

#ifndef Safefree
#  define Safefree(p)           free((p))
#endif

#endif /* _PPPORT_H_ */
